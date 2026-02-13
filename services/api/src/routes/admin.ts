import bcrypt from "bcryptjs";
import { DateTime } from "luxon";
import type { FastifyPluginAsync } from "fastify";
import {
  adminLoginRequestSchema,
  adminPickupAvailabilityResponseSchema,
  createAdminUserRequestSchema,
  delayOrderRequestSchema,
  finalizeOrderRequestSchema,
  fulfillOrderResponseSchema,
  patchOrderStatusRequestSchema,
  patchStockRequestSchema,
  refundOrderRequestSchema,
  togglePickupSlotUnavailableRequestSchema,
  updatePickupDayRangeRequestSchema,
  upsertProductRequestSchema,
  orderStatusSchema
} from "@oasis/contracts";
import {
  applyOrderDelay,
  createAdminUser,
  createRefund,
  createProduct,
  getDailySlotBookings,
  getOrderById,
  getPickupDayRanges,
  getReceiptByOrderId,
  getRefundedAmount,
  getStoreConfig,
  listAdminProducts,
  listOrderItems,
  listOrders,
  listUnavailableSlots,
  patchOrderStatus,
  patchProduct,
  patchProductStock,
  restoreStockForOrder,
  saveReceipt,
  setSlotUnavailable,
  updateFinalizedOrderItem,
  updateOrderFinalTotals,
  updateOrderPaymentStatus,
  upsertPickupDayRange
} from "../db/repositories.js";
import { withTransaction } from "../db/pool.js";
import { buildTotals } from "../services/orderCalculation.js";
import {
  buildPickupSlotsForDate,
  getDayBoundaryIso,
  getHourlyRangeFromStoreConfig
} from "../services/pickupSlots.js";
import { buildCustomerReceiptPdf } from "../services/receipts.js";
import { issueAdminTokens, verifyAdminPassword } from "../auth/adminAuth.js";
import { slotShiftHoursForDelay } from "../utils/delayRules.js";
import { assertValidStatusTransition } from "../utils/statusFlow.js";
import { clampRefundAmount } from "../utils/refundMath.js";
import { mapDbProductToContract } from "./mappers.js";

const isDateInAllowedWindow = (date: string, timezone: string): boolean => {
  const day = DateTime.fromISO(date, { zone: timezone }).startOf("day");
  if (!day.isValid) {
    return false;
  }

  const today = DateTime.now().setZone(timezone).startOf("day");
  const tomorrow = today.plus({ days: 1 });
  return day.hasSame(today, "day") || day.hasSame(tomorrow, "day");
};

const getAllowedDates = (timezone: string): string[] => {
  const today = DateTime.now().setZone(timezone).startOf("day");
  const tomorrow = today.plus({ days: 1 });
  return [today.toISODate(), tomorrow.toISODate()].filter(
    (value): value is string => Boolean(value)
  );
};

const adminRoutes: FastifyPluginAsync = async (app) => {
  app.post("/admin/auth/login", async (request, reply) => {
    const parsed = adminLoginRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ message: parsed.error.flatten() });
    }

    const admin = await verifyAdminPassword(parsed.data.email, parsed.data.password);
    if (!admin) {
      return reply.code(401).send({ message: "Invalid credentials" });
    }

    const tokens = await issueAdminTokens(app, {
      adminId: admin.id,
      role: admin.role
    });

    return reply.send({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      role: admin.role
    });
  });

  app.post(
    "/admin/users",
    {
      preHandler: [app.authenticateAdmin, app.authorizeSuperadmin]
    },
    async (request, reply) => {
      const parsed = createAdminUserRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const hash = await bcrypt.hash(parsed.data.password, 12);
      const user = await createAdminUser(parsed.data.email, hash, parsed.data.role);
      return reply.code(201).send({
        id: user.id,
        email: user.email,
        role: user.role
      });
    }
  );

  app.get(
    "/admin/products",
    {
      preHandler: [app.authenticateAdmin]
    },
    async () => {
      const products = await listAdminProducts();
      return {
        products: products.map(mapDbProductToContract)
      };
    }
  );

  app.post(
    "/admin/products",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const parsed = upsertProductRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const product = await createProduct(parsed.data);
      return reply.code(201).send(mapDbProductToContract(product));
    }
  );

  app.patch(
    "/admin/products/:id",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = upsertProductRequestSchema.partial().safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const product = await patchProduct(id, parsed.data);
      if (!product) {
        return reply.code(404).send({ message: "Product not found" });
      }

      return reply.send(mapDbProductToContract(product));
    }
  );

  app.patch(
    "/admin/products/:id/stock",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = patchStockRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const product = await patchProductStock(id, parsed.data.stockQuantity);
      if (!product) {
        return reply.code(404).send({ message: "Product not found" });
      }

      return reply.send(mapDbProductToContract(product));
    }
  );

  app.get(
    "/admin/pickup-availability",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (_request, reply) => {
      const config = await getStoreConfig();
      const allowedDates = getAllowedDates(config.timezone);
      const ranges = await getPickupDayRanges(allowedDates);
      const defaultRange = getHourlyRangeFromStoreConfig(config);

      const days = await Promise.all(
        allowedDates.map(async (date) => {
          const { dayStartIso, dayEndIso } = getDayBoundaryIso(date, config.timezone);
          const bookings = await getDailySlotBookings(dayStartIso, dayEndIso);
          const unavailable = await listUnavailableSlots(dayStartIso, dayEndIso);
          const override = ranges.get(date);

          const slots = buildPickupSlotsForDate(
            date,
            {
              timezone: config.timezone,
              slotCapacity: config.slotCapacity,
              leadTimeMinutes: 0,
              openHour: override?.openHour ?? defaultRange.openHour,
              closeHour: override?.closeHour ?? defaultRange.closeHour,
              unavailableSlotStarts: unavailable
            },
            bookings,
            DateTime.fromISO(date, { zone: config.timezone }).startOf("day")
          );

          return {
            date,
            openHour: override?.openHour ?? defaultRange.openHour,
            closeHour: override?.closeHour ?? defaultRange.closeHour,
            slots: slots.map((slot) => {
              const booked = bookings.get(slot.startIso) ?? 0;
              const isUnavailable = unavailable.has(slot.startIso);
              return {
                startIso: slot.startIso,
                endIso: slot.endIso,
                capacity: slot.capacity,
                booked,
                available: slot.available,
                isUnavailable
              };
            })
          };
        })
      );

      return reply.send(adminPickupAvailabilityResponseSchema.parse({ days }));
    }
  );

  app.put(
    "/admin/pickup-availability/:date/range",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { date } = request.params as { date: string };
      const parsed = updatePickupDayRangeRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const config = await getStoreConfig();
      if (!isDateInAllowedWindow(date, config.timezone)) {
        return reply.code(400).send({ message: "Date must be today or tomorrow" });
      }

      if (parsed.data.closeHour <= parsed.data.openHour) {
        return reply
          .code(400)
          .send({ message: "closeHour must be greater than openHour" });
      }

      await upsertPickupDayRange(date, parsed.data.openHour, parsed.data.closeHour);

      return reply.send({
        date,
        openHour: parsed.data.openHour,
        closeHour: parsed.data.closeHour
      });
    }
  );

  app.put(
    "/admin/pickup-slots/:slotStartIso/unavailable",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { slotStartIso } = request.params as { slotStartIso: string };
      const parsed = togglePickupSlotUnavailableRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const decoded = decodeURIComponent(slotStartIso);
      const slotStart = DateTime.fromISO(decoded, { zone: "utc" });
      if (!slotStart.isValid) {
        return reply.code(400).send({ message: "Invalid slot start ISO" });
      }

      const config = await getStoreConfig();
      const serviceDate = slotStart.setZone(config.timezone).toISODate();
      if (!serviceDate || !isDateInAllowedWindow(serviceDate, config.timezone)) {
        return reply.code(400).send({ message: "Slot must be for today or tomorrow" });
      }

      const slotEnd = slotStart.plus({ hours: 1 });
      const slotStartIsoNormalized = slotStart.toISO();
      const slotEndIsoNormalized = slotEnd.toISO();

      if (!slotStartIsoNormalized || !slotEndIsoNormalized) {
        return reply.code(400).send({ message: "Invalid slot window" });
      }

      await setSlotUnavailable(
        slotStartIsoNormalized,
        slotEndIsoNormalized,
        serviceDate,
        parsed.data.unavailable
      );

      return reply.send({
        slotStartIso: slotStartIsoNormalized,
        unavailable: parsed.data.unavailable
      });
    }
  );

  app.get(
    "/admin/orders",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const query = request.query as { status?: string };
      const status = query.status ? orderStatusSchema.parse(query.status) : undefined;
      const orders = await listOrders(status);
      return reply.send({ orders });
    }
  );

  app.patch(
    "/admin/orders/:id/status",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = patchOrderStatusRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const current = await getOrderById(id);
      if (!current) {
        return reply.code(404).send({ message: "Order not found" });
      }

      try {
        assertValidStatusTransition(current.status, parsed.data.status);
      } catch (error) {
        return reply.code(409).send({
          message: error instanceof Error ? error.message : "Invalid status transition"
        });
      }

      if (
        parsed.data.status === "cancelled" &&
        current.status !== "cancelled" &&
        current.status !== "refunded"
      ) {
        await withTransaction(async (client) => {
          await restoreStockForOrder(client, id);
          await client.query(
            `UPDATE orders
             SET status = $2,
                 updated_at = NOW()
             WHERE id = $1`,
            [id, parsed.data.status]
          );
        });

        const updated = await getOrderById(id);
        return reply.send(updated);
      }

      const updated = await patchOrderStatus(id, parsed.data.status);
      return reply.send(updated);
    }
  );

  app.post(
    "/admin/orders/:id/delay",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = delayOrderRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const order = await getOrderById(id);
      if (!order) {
        return reply.code(404).send({ message: "Order not found" });
      }

      if (order.status === "cancelled" || order.status === "refunded") {
        return reply.code(409).send({ message: "Order cannot be delayed" });
      }

      const shiftHours = slotShiftHoursForDelay(parsed.data.delayMinutes);
      const updated = await applyOrderDelay(id, parsed.data.delayMinutes, shiftHours);
      if (!updated) {
        return reply.code(500).send({ message: "Failed to delay order" });
      }

      return reply.send(updated);
    }
  );

  app.post(
    "/admin/orders/:id/finalize",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = finalizeOrderRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const order = await getOrderById(id);
      if (!order) {
        return reply.code(404).send({ message: "Order not found" });
      }

      const items = await listOrderItems(id);
      const byId = new Map(items.map((item) => [item.id, item]));
      const config = await getStoreConfig();

      for (const input of parsed.data.items) {
        const currentItem = byId.get(input.orderItemId);
        if (!currentItem) {
          return reply.code(400).send({ message: `Unknown order item ${input.orderItemId}` });
        }

        const finalQuantity =
          currentItem.productUnitSnapshot === "each"
            ? (input.finalQuantity ?? currentItem.estimatedQuantity ?? 1)
            : null;

        const finalWeight =
          currentItem.productUnitSnapshot === "lb"
            ? (input.finalWeightLb ?? currentItem.estimatedWeightLb ?? 0)
            : null;

        const multiplier = finalWeight ?? finalQuantity ?? 0;
        const lineSubtotal = Math.round(currentItem.productPriceCentsSnapshot * multiplier);

        await updateFinalizedOrderItem(
          currentItem.id,
          finalQuantity,
          finalWeight,
          lineSubtotal
        );
      }

      const refreshedItems = await listOrderItems(id);
      const finalSubtotalCents = refreshedItems.reduce((sum, item) => {
        return sum + (item.finalLineSubtotalCents ?? item.estimatedLineSubtotalCents);
      }, 0);

      const totals = buildTotals(finalSubtotalCents, config.taxRateBps);
      const updated = await updateOrderFinalTotals(
        id,
        totals.subtotalCents,
        totals.taxCents,
        totals.totalCents
      );

      return reply.send(updated);
    }
  );

  app.post(
    "/admin/orders/:id/refund",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = refundOrderRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ message: parsed.error.flatten() });
      }

      const order = await getOrderById(id);
      if (!order) {
        return reply.code(404).send({ message: "Order not found" });
      }
      if (!order.paymentIntentId) {
        return reply.code(409).send({ message: "Order has no payment intent" });
      }

      const paidCents = order.finalTotalCents ?? order.estimatedTotalCents;
      const alreadyRefunded = await getRefundedAmount(order.id);
      const refundable = clampRefundAmount(
        parsed.data.amountCents,
        alreadyRefunded,
        paidCents
      );

      if (refundable <= 0) {
        return reply.code(409).send({ message: "No refundable amount remaining" });
      }

      const providerRefund = await app.paymentProvider.refund(
        order.paymentIntentId,
        refundable,
        parsed.data.reason
      );

      await createRefund(order.id, refundable, parsed.data.reason, providerRefund.refundId);

      const totalRefunded = alreadyRefunded + refundable;
      if (totalRefunded >= paidCents) {
        await updateOrderPaymentStatus(order.id, "fully_refunded");
        await patchOrderStatus(order.id, "refunded");
      } else {
        await updateOrderPaymentStatus(order.id, "partially_refunded");
      }

      const updatedOrder = await getOrderById(order.id);
      return reply.send({
        refundedCents: refundable,
        order: updatedOrder
      });
    }
  );

  app.post(
    "/admin/orders/:id/fulfill",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const order = await getOrderById(id);
      if (!order) {
        return reply.code(404).send({ message: "Order not found" });
      }

      const items = await listOrderItems(id);
      const pdf = await buildCustomerReceiptPdf(order, items);
      const pdfKey = `receipts/${order.orderNumber}.pdf`;

      await app.storageProvider.putObject(pdfKey, pdf, "application/pdf");
      await saveReceipt(order.id, pdfKey);

      const finalizedOrder =
        order.status === "fulfilled" ? order : await patchOrderStatus(order.id, "fulfilled");
      if (!finalizedOrder) {
        return reply.code(500).send({ message: "Failed to set fulfilled status" });
      }

      const escposPayload = app.printerFormatter.buildEscPosReceipt(finalizedOrder, items);
      const receiptUrl = await app.storageProvider.getSignedUrl(pdfKey);

      return reply.send(
        fulfillOrderResponseSchema.parse({
          receiptUrl,
          escposPayloadBase64: escposPayload.toString("base64")
        })
      );
    }
  );

  app.get(
    "/admin/orders/:id/receipt/escpos",
    {
      preHandler: [app.authenticateAdmin]
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const order = await getOrderById(id);
      if (!order) {
        return reply.code(404).send({ message: "Order not found" });
      }

      const items = await listOrderItems(id);
      const payload = app.printerFormatter.buildEscPosReceipt(order, items);
      const receipt = await getReceiptByOrderId(order.id);
      const receiptUrl = receipt
        ? await app.storageProvider.getSignedUrl(receipt.pdfKey)
        : null;

      return reply.send({
        orderId: order.id,
        orderNumber: order.orderNumber,
        receiptUrl,
        escposPayloadBase64: payload.toString("base64")
      });
    }
  );
};

export default adminRoutes;
