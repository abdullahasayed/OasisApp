import type { LookupOrderResponse, Product } from "@oasis/contracts";
import type { DbOrder, DbProduct } from "../db/repositories.js";

export const mapDbProductToContract = (product: DbProduct): Product => ({
  id: product.id,
  name: product.name,
  description: product.description,
  category: product.category,
  unit: product.unit,
  priceCents: product.priceCents,
  stockQuantity: product.stockQuantity,
  imageUrl: product.imageUrl,
  imageKey: product.imageKey,
  active: product.active,
  createdAt: product.createdAt,
  updatedAt: product.updatedAt
});

export const mapDbOrderToLookup = (
  order: DbOrder,
  receiptUrl: string | null
): LookupOrderResponse => ({
  id: order.id,
  orderNumber: order.orderNumber,
  customerName: order.customerName,
  customerPhone: order.customerPhone,
  pickupSlotStartIso: order.pickupSlotStartIso,
  pickupSlotEndIso: order.pickupSlotEndIso,
  status: order.status,
  paymentStatus: order.paymentStatus,
  estimatedSubtotalCents: order.estimatedSubtotalCents,
  estimatedTaxCents: order.estimatedTaxCents,
  estimatedTotalCents: order.estimatedTotalCents,
  finalSubtotalCents: order.finalSubtotalCents,
  finalTaxCents: order.finalTaxCents,
  finalTotalCents: order.finalTotalCents,
  receiptUrl
});
