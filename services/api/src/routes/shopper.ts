import { randomUUID } from "node:crypto";
import { DateTime } from "luxon";
import type { FastifyPluginAsync } from "fastify";
import {
  catalogQuerySchema,
  createOrderRequestSchema,
  createOrderResponseSchema,
  lookupOrderResponseSchema
} from "@oasis/contracts";
import {
  decrementStockForOrder,
  getDailySlotBookings,
  getOrderById,
  getOrderByLookup,
  getPickupDayRanges,
  getProductsByIds,
  getReceiptByOrderId,
  getSlotBookingsCount,
  getStoreConfig,
  insertDailySequenceAndGet,
  insertOrder,
  insertOrderItems,
  listCatalogProducts,
  listUnavailableSlots,
  getProductById
} from "../db/repositories.js";
import { withTransaction } from "../db/pool.js";
import {
  buildPickupSlotsForDate,
  getDayBoundaryIso,
  getHourlyRangeFromStoreConfig
} from "../services/pickupSlots.js";
import { buildEstimatedLines, buildTotals } from "../services/orderCalculation.js";
import { buildOrderNumber } from "../utils/orderNumber.js";
import { normalizePhone } from "../utils/phone.js";
import { mapDbOrderToLookup, mapDbProductToContract } from "./mappers.js";

const shopperRoutes: FastifyPluginAsync = async (app) => {
  app.get("/catalog", async (request, reply) => {
    const parsed = catalogQuerySchema.safeParse(request.query ?? {});
    if (!parsed.success) {
      return reply.code(400).send({ message: parsed.error.flatten() });
    }

    const queryText = parsed.data.q?.trim() ?? "";
    const products = await listCatalogProducts({
      category: queryText ? undefined : parsed.data.category,
      q: queryText || undefined,
      limit: parsed.data.limit
    });
    return reply.send({
      products: products.map(mapDbProductToContract)
    });
  });

  app.get("/products/:id", async (request, reply) => {
    const { id } = request.params as { id: string };
    const product = await getProductById(id);
    if (!product) {
      return reply.code(404).send({ message: "Product not found" });
    }

    return reply.send(mapDbProductToContract(product));
  });

  app.get("/pickup-slots", async (request) => {
    const query = request.query as { date?: string };
    const date = query.date ?? DateTime.now().toISODate();
    if (!date) {
      return { slots: [] };
    }

    const config = await getStoreConfig();
    const { dayStartIso, dayEndIso } = getDayBoundaryIso(date, config.timezone);
    const bookings = await getDailySlotBookings(dayStartIso, dayEndIso);
    const unavailableSlots = await listUnavailableSlots(dayStartIso, dayEndIso);
    const dayRanges = await getPickupDayRanges([date]);
    const defaultRange = getHourlyRangeFromStoreConfig(config);
    const range = dayRanges.get(date);

    const slots = buildPickupSlotsForDate(
      date,
      {
        timezone: config.timezone,
        slotCapacity: config.slotCapacity,
        leadTimeMinutes: config.leadTimeMinutes,
        openHour: range?.openHour ?? defaultRange.openHour,
        closeHour: range?.closeHour ?? defaultRange.closeHour,
        unavailableSlotStarts: unavailableSlots
      },
      bookings
    );
    return { slots };
  });

  app.post("/orders", async (request, reply) => {
    const parsed = createOrderRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ message: parsed.error.flatten() });
    }

    const payload = parsed.data;
    const normalizedPhone = normalizePhone(payload.customerPhone);

    const config = await getStoreConfig();

    const slotDate = DateTime.fromISO(payload.pickupSlotStartIso, {
      zone: config.timezone
    }).toISODate();

    if (!slotDate) {
      return reply.code(400).send({ message: "Invalid pickup slot date" });
    }

    const { dayStartIso, dayEndIso } = getDayBoundaryIso(slotDate, config.timezone);
    const bookings = await getDailySlotBookings(dayStartIso, dayEndIso);
    const unavailableSlots = await listUnavailableSlots(dayStartIso, dayEndIso);
    const dayRanges = await getPickupDayRanges([slotDate]);
    const defaultRange = getHourlyRangeFromStoreConfig(config);
    const range = dayRanges.get(slotDate);

    const slots = buildPickupSlotsForDate(
      slotDate,
      {
        timezone: config.timezone,
        slotCapacity: config.slotCapacity,
        leadTimeMinutes: config.leadTimeMinutes,
        openHour: range?.openHour ?? defaultRange.openHour,
        closeHour: range?.closeHour ?? defaultRange.closeHour,
        unavailableSlotStarts: unavailableSlots
      },
      bookings
    );

    const selectedSlot = slots.find((slot) => slot.startIso === payload.pickupSlotStartIso);

    if (!selectedSlot) {
      return reply.code(400).send({ message: "Invalid pickup slot" });
    }

    if (selectedSlot.available <= 0) {
      return reply.code(409).send({ message: "Pickup slot is full" });
    }

    const products = await getProductsByIds(payload.items.map((item) => item.productId));
    const productsById = new Map(products.map((product) => [product.id, product]));

    for (const item of payload.items) {
      const product = productsById.get(item.productId);
      if (!product || !product.active) {
        return reply.code(400).send({
          message: `Product ${item.productId} is unavailable`
        });
      }
    }

    const pricedLines = payload.items.map((item) => {
      const product = productsById.get(item.productId)!;
      return {
        productId: product.id,
        unit: product.unit,
        priceCents: product.priceCents,
        requestedQuantity: item.quantity,
        requestedWeightLb: item.estimatedWeightLb
      };
    });

    const { estimatedLines, estimatedSubtotalCents } = buildEstimatedLines(pricedLines);
    const totals = buildTotals(estimatedSubtotalCents, config.taxRateBps);

    for (const line of estimatedLines) {
      const product = productsById.get(line.productId)!;
      if (product.stockQuantity < line.quantityToReserve) {
        return reply.code(409).send({
          message: `Insufficient stock for ${product.name}`
        });
      }
    }

    try {
      const created = await withTransaction(async (client) => {
        const bookedCount = await getSlotBookingsCount(client, selectedSlot.startIso);
        if (bookedCount >= config.slotCapacity) {
          throw new Error("Selected pickup slot became full");
        }

        const orderId = randomUUID();
        const orderDateKey = DateTime.fromISO(selectedSlot.startIso, {
          zone: config.timezone
        }).toFormat("yyyy-MM-dd");
        const seq = await insertDailySequenceAndGet(client, orderDateKey);
        const orderNumber = buildOrderNumber(
          DateTime.fromISO(selectedSlot.startIso).toJSDate(),
          seq
        );

        const paymentIntent = await app.paymentProvider.createPaymentIntent({
          orderId,
          orderNumber,
          amountCents: totals.totalCents,
          currency: "usd",
          customerName: payload.customerName,
          customerPhone: normalizedPhone
        });

        const order = await insertOrder(client, {
          orderId,
          orderNumber,
          customerName: payload.customerName,
          customerPhone: normalizedPhone,
          pickupSlotStartIso: selectedSlot.startIso,
          pickupSlotEndIso: selectedSlot.endIso,
          requestedPickupSlotStartIso: selectedSlot.startIso,
          requestedPickupSlotEndIso: selectedSlot.endIso,
          estimatedPickupStartIso: selectedSlot.startIso,
          estimatedPickupEndIso: selectedSlot.endIso,
          totalDelayMinutes: 0,
          status: "placed",
          paymentStatus: "pending",
          estimatedSubtotalCents: totals.subtotalCents,
          estimatedTaxCents: totals.taxCents,
          estimatedTotalCents: totals.totalCents,
          paymentIntentId: paymentIntent.paymentIntentId,
          paymentClientSecret: paymentIntent.clientSecret,
          paymentProvider: app.paymentProvider.providerName
        });

        await insertOrderItems(
          client,
          estimatedLines.map((line) => {
            const product = productsById.get(line.productId)!;
            return {
              orderId: order.id,
              productId: line.productId,
              productNameSnapshot: product.name,
              productUnitSnapshot: product.unit,
              productPriceCentsSnapshot: product.priceCents,
              estimatedQuantity: line.estimatedQuantity,
              estimatedWeightLb: line.estimatedWeightLb,
              estimatedLineSubtotalCents: line.estimatedLineSubtotalCents
            };
          })
        );

        await decrementStockForOrder(
          client,
          estimatedLines.map((line) => ({
            productId: line.productId,
            quantityToReserve: line.quantityToReserve
          }))
        );

        return {
          order,
          paymentClientSecret: paymentIntent.clientSecret
        };
      });

      const response = createOrderResponseSchema.parse({
        orderId: created.order.id,
        orderNumber: created.order.orderNumber,
        paymentClientSecret: created.paymentClientSecret,
        estimatedTotalCents: created.order.estimatedTotalCents,
        status: created.order.status
      });

      return reply.code(201).send(response);
    } catch (error) {
      request.log.error({ error }, "Failed to create order");
      return reply.code(409).send({
        message: error instanceof Error ? error.message : "Order creation failed"
      });
    }
  });

  app.get("/orders/lookup", async (request, reply) => {
    const query = request.query as { orderNumber?: string; phone?: string };
    if (!query.orderNumber || !query.phone) {
      return reply.code(400).send({
        message: "orderNumber and phone are required"
      });
    }

    const order = await getOrderByLookup(query.orderNumber, normalizePhone(query.phone));
    if (!order) {
      return reply.code(404).send({ message: "Order not found" });
    }

    const receipt = await getReceiptByOrderId(order.id);
    const receiptUrl = receipt
      ? await app.storageProvider.getSignedUrl(receipt.pdfKey)
      : null;

    return reply.send(lookupOrderResponseSchema.parse(mapDbOrderToLookup(order, receiptUrl)));
  });

  app.get("/orders/:id/receipt", async (request, reply) => {
    const { id } = request.params as { id: string };
    const order = await getOrderById(id);
    if (!order) {
      return reply.code(404).send({ message: "Order not found" });
    }

    const receipt = await getReceiptByOrderId(order.id);
    if (!receipt) {
      return reply.code(404).send({ message: "Receipt not found" });
    }

    if (app.storageProvider.getObject) {
      const content = await app.storageProvider.getObject(receipt.pdfKey);
      reply.header("content-type", "application/pdf");
      reply.header(
        "content-disposition",
        `inline; filename=order-${order.orderNumber}.pdf`
      );
      return reply.send(content);
    }

    const signedUrl = await app.storageProvider.getSignedUrl(receipt.pdfKey);
    return reply.redirect(signedUrl);
  });

  app.get("/storage/local/*", async (request, reply) => {
    if (!app.storageProvider.getObject) {
      return reply.code(404).send({ message: "Local storage route disabled" });
    }

    const key = (request.params as { "*": string })["*"];
    const decoded = decodeURIComponent(key);
    const content = await app.storageProvider.getObject(decoded);

    const type = decoded.endsWith(".pdf") ? "application/pdf" : "application/octet-stream";
    reply.header("content-type", type);
    return reply.send(content);
  });
};

export default shopperRoutes;
