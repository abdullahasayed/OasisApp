import { z } from "zod";

export const productCategorySchema = z.enum([
  "halal_meat",
  "fruits",
  "vegetables",
  "grocery_other"
]);
export type ProductCategory = z.infer<typeof productCategorySchema>;

export const productUnitSchema = z.enum(["each", "lb"]);
export type ProductUnit = z.infer<typeof productUnitSchema>;

export const orderStatusSchema = z.enum([
  "placed",
  "preparing",
  "ready",
  "fulfilled",
  "delayed",
  "cancelled",
  "refunded"
]);
export type OrderStatus = z.infer<typeof orderStatusSchema>;

export const paymentStatusSchema = z.enum([
  "pending",
  "paid_estimated",
  "partially_refunded",
  "fully_refunded"
]);
export type PaymentStatus = z.infer<typeof paymentStatusSchema>;

export const adminRoleSchema = z.enum(["superadmin", "admin"]);
export type AdminRole = z.infer<typeof adminRoleSchema>;

export const moneyCentsSchema = z.number().int().nonnegative();

export const hourOfDaySchema = z.number().int().min(0).max(23);

export const phoneSchema = z
  .string()
  .trim()
  .min(7)
  .max(20)
  .regex(/^[0-9+\-()\s]+$/);

export const productSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(2),
  description: z.string().default(""),
  category: productCategorySchema,
  unit: productUnitSchema,
  priceCents: moneyCentsSchema,
  stockQuantity: z.number().nonnegative(),
  imageUrl: z.string().url(),
  imageKey: z.string(),
  active: z.boolean(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime()
});
export type Product = z.infer<typeof productSchema>;

export const catalogQuerySchema = z.object({
  category: productCategorySchema.optional(),
  q: z.string().trim().max(80).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100)
});
export type CatalogQuery = z.infer<typeof catalogQuerySchema>;

export const catalogResponseSchema = z.object({
  products: z.array(productSchema)
});
export type CatalogResponse = z.infer<typeof catalogResponseSchema>;

export const pickupSlotSchema = z.object({
  startIso: z.string().datetime(),
  endIso: z.string().datetime(),
  capacity: z.number().int().nonnegative(),
  available: z.number().int().nonnegative()
});
export type PickupSlot = z.infer<typeof pickupSlotSchema>;

export const pickupSlotsResponseSchema = z.object({
  slots: z.array(pickupSlotSchema)
});
export type PickupSlotsResponse = z.infer<typeof pickupSlotsResponseSchema>;

export const createOrderItemInputSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().positive().default(1),
  estimatedWeightLb: z.number().positive().optional()
});
export type CreateOrderItemInput = z.infer<typeof createOrderItemInputSchema>;

export const createOrderRequestSchema = z.object({
  customerName: z.string().trim().min(2),
  customerPhone: phoneSchema,
  pickupSlotStartIso: z.string().datetime(),
  items: z.array(createOrderItemInputSchema).min(1)
});
export type CreateOrderRequest = z.infer<typeof createOrderRequestSchema>;

export const createOrderResponseSchema = z.object({
  orderId: z.string().uuid(),
  orderNumber: z.string(),
  paymentClientSecret: z.string(),
  estimatedTotalCents: moneyCentsSchema,
  status: orderStatusSchema
});
export type CreateOrderResponse = z.infer<typeof createOrderResponseSchema>;

export const lookupOrderResponseSchema = z.object({
  id: z.string().uuid(),
  orderNumber: z.string(),
  customerName: z.string(),
  customerPhone: phoneSchema,
  pickupSlotStartIso: z.string().datetime(),
  pickupSlotEndIso: z.string().datetime(),
  estimatedPickupStartIso: z.string().datetime(),
  estimatedPickupEndIso: z.string().datetime(),
  totalDelayMinutes: z.number().int().nonnegative(),
  status: orderStatusSchema,
  paymentStatus: paymentStatusSchema,
  estimatedSubtotalCents: moneyCentsSchema,
  estimatedTaxCents: moneyCentsSchema,
  estimatedTotalCents: moneyCentsSchema,
  finalSubtotalCents: moneyCentsSchema.nullable(),
  finalTaxCents: moneyCentsSchema.nullable(),
  finalTotalCents: moneyCentsSchema.nullable(),
  receiptUrl: z.string().url().nullable()
});
export type LookupOrderResponse = z.infer<typeof lookupOrderResponseSchema>;

export const adminLoginRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});
export type AdminLoginRequest = z.infer<typeof adminLoginRequestSchema>;

export const adminLoginResponseSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  role: adminRoleSchema
});
export type AdminLoginResponse = z.infer<typeof adminLoginResponseSchema>;

export const createAdminUserRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  role: adminRoleSchema
});
export type CreateAdminUserRequest = z.infer<typeof createAdminUserRequestSchema>;

export const upsertProductRequestSchema = z.object({
  name: z.string().trim().min(2),
  description: z.string().default(""),
  category: productCategorySchema,
  unit: productUnitSchema,
  priceCents: moneyCentsSchema,
  stockQuantity: z.number().nonnegative(),
  imageKey: z.string(),
  imageUrl: z.string().url(),
  active: z.boolean().default(true)
});
export type UpsertProductRequest = z.infer<typeof upsertProductRequestSchema>;

export const patchStockRequestSchema = z.object({
  stockQuantity: z.number().nonnegative()
});
export type PatchStockRequest = z.infer<typeof patchStockRequestSchema>;

export const patchOrderStatusRequestSchema = z.object({
  status: orderStatusSchema
});
export type PatchOrderStatusRequest = z.infer<typeof patchOrderStatusRequestSchema>;

export const delayMinutesSchema = z.union([
  z.literal(10),
  z.literal(30),
  z.literal(60),
  z.literal(90)
]);
export type DelayMinutes = z.infer<typeof delayMinutesSchema>;

export const delayOrderRequestSchema = z.object({
  delayMinutes: delayMinutesSchema
});
export type DelayOrderRequest = z.infer<typeof delayOrderRequestSchema>;

export const finalizeOrderItemSchema = z.object({
  orderItemId: z.string().uuid(),
  finalWeightLb: z.number().positive().optional(),
  finalQuantity: z.number().positive().optional()
});
export type FinalizeOrderItem = z.infer<typeof finalizeOrderItemSchema>;

export const finalizeOrderRequestSchema = z.object({
  items: z.array(finalizeOrderItemSchema).min(1)
});
export type FinalizeOrderRequest = z.infer<typeof finalizeOrderRequestSchema>;

export const refundOrderRequestSchema = z.object({
  amountCents: moneyCentsSchema,
  reason: z.string().trim().min(2)
});
export type RefundOrderRequest = z.infer<typeof refundOrderRequestSchema>;

export const fulfillOrderResponseSchema = z.object({
  receiptUrl: z.string().url(),
  escposPayloadBase64: z.string()
});
export type FulfillOrderResponse = z.infer<typeof fulfillOrderResponseSchema>;

export const adminPickupSlotSchema = z.object({
  startIso: z.string().datetime(),
  endIso: z.string().datetime(),
  capacity: z.number().int().nonnegative(),
  booked: z.number().int().nonnegative(),
  available: z.number().int().nonnegative(),
  isUnavailable: z.boolean()
});
export type AdminPickupSlot = z.infer<typeof adminPickupSlotSchema>;

export const adminPickupDaySchema = z.object({
  date: z.string().date(),
  openHour: hourOfDaySchema,
  closeHour: z.number().int().min(1).max(24),
  slots: z.array(adminPickupSlotSchema)
});
export type AdminPickupDay = z.infer<typeof adminPickupDaySchema>;

export const adminPickupAvailabilityResponseSchema = z.object({
  days: z.array(adminPickupDaySchema)
});
export type AdminPickupAvailabilityResponse = z.infer<
  typeof adminPickupAvailabilityResponseSchema
>;

export const updatePickupDayRangeRequestSchema = z.object({
  openHour: hourOfDaySchema,
  closeHour: z.number().int().min(1).max(24)
});
export type UpdatePickupDayRangeRequest = z.infer<
  typeof updatePickupDayRangeRequestSchema
>;

export const togglePickupSlotUnavailableRequestSchema = z.object({
  unavailable: z.boolean()
});
export type TogglePickupSlotUnavailableRequest = z.infer<
  typeof togglePickupSlotUnavailableRequestSchema
>;

export const taxConfigSchema = z.object({
  rateBps: z.number().int().min(0).max(10000)
});
export type TaxConfig = z.infer<typeof taxConfigSchema>;
