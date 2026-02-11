import type {
  AdminRole,
  OrderStatus,
  PaymentStatus,
  ProductCategory,
  ProductUnit,
  UpsertProductRequest
} from "@oasis/contracts";
import type { PoolClient } from "pg";
import { query } from "./pool.js";

export interface DbProduct {
  id: string;
  name: string;
  description: string;
  category: ProductCategory;
  unit: ProductUnit;
  priceCents: number;
  stockQuantity: number;
  imageKey: string;
  imageUrl: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface DbOrder {
  id: string;
  orderNumber: string;
  customerName: string;
  customerPhone: string;
  pickupSlotStartIso: string;
  pickupSlotEndIso: string;
  status: OrderStatus;
  paymentStatus: PaymentStatus;
  estimatedSubtotalCents: number;
  estimatedTaxCents: number;
  estimatedTotalCents: number;
  finalSubtotalCents: number | null;
  finalTaxCents: number | null;
  finalTotalCents: number | null;
  paymentIntentId: string | null;
  paymentClientSecret: string | null;
  paymentProvider: string;
  createdAt: string;
  updatedAt: string;
}

export interface DbOrderItem {
  id: string;
  orderId: string;
  productId: string;
  productNameSnapshot: string;
  productUnitSnapshot: ProductUnit;
  productPriceCentsSnapshot: number;
  estimatedQuantity: number | null;
  estimatedWeightLb: number | null;
  estimatedLineSubtotalCents: number;
  finalQuantity: number | null;
  finalWeightLb: number | null;
  finalLineSubtotalCents: number | null;
  createdAt: string;
}

export interface StoreConfig {
  timezone: string;
  openTime: string;
  closeTime: string;
  slotMinutes: number;
  slotCapacity: number;
  leadTimeMinutes: number;
  taxRateBps: number;
}

export interface AdminUser {
  id: string;
  email: string;
  passwordHash: string;
  role: AdminRole;
}

const mapProduct = (row: Record<string, unknown>): DbProduct => ({
  id: row.id as string,
  name: row.name as string,
  description: row.description as string,
  category: row.category as ProductCategory,
  unit: row.unit as ProductUnit,
  priceCents: Number(row.price_cents),
  stockQuantity: Number(row.stock_quantity),
  imageKey: row.image_key as string,
  imageUrl: row.image_url as string,
  active: Boolean(row.active),
  createdAt: (row.created_at as Date).toISOString(),
  updatedAt: (row.updated_at as Date).toISOString()
});

const mapOrder = (row: Record<string, unknown>): DbOrder => ({
  id: row.id as string,
  orderNumber: row.order_number as string,
  customerName: row.customer_name as string,
  customerPhone: row.customer_phone as string,
  pickupSlotStartIso: (row.pickup_slot_start as Date).toISOString(),
  pickupSlotEndIso: (row.pickup_slot_end as Date).toISOString(),
  status: row.status as OrderStatus,
  paymentStatus: row.payment_status as PaymentStatus,
  estimatedSubtotalCents: Number(row.estimated_subtotal_cents),
  estimatedTaxCents: Number(row.estimated_tax_cents),
  estimatedTotalCents: Number(row.estimated_total_cents),
  finalSubtotalCents:
    row.final_subtotal_cents === null ? null : Number(row.final_subtotal_cents),
  finalTaxCents: row.final_tax_cents === null ? null : Number(row.final_tax_cents),
  finalTotalCents:
    row.final_total_cents === null ? null : Number(row.final_total_cents),
  paymentIntentId: (row.payment_intent_id as string | null) ?? null,
  paymentClientSecret: (row.payment_client_secret as string | null) ?? null,
  paymentProvider: row.payment_provider as string,
  createdAt: (row.created_at as Date).toISOString(),
  updatedAt: (row.updated_at as Date).toISOString()
});

const mapOrderItem = (row: Record<string, unknown>): DbOrderItem => ({
  id: row.id as string,
  orderId: row.order_id as string,
  productId: row.product_id as string,
  productNameSnapshot: row.product_name_snapshot as string,
  productUnitSnapshot: row.product_unit_snapshot as ProductUnit,
  productPriceCentsSnapshot: Number(row.product_price_cents_snapshot),
  estimatedQuantity:
    row.estimated_quantity === null ? null : Number(row.estimated_quantity),
  estimatedWeightLb:
    row.estimated_weight_lb === null ? null : Number(row.estimated_weight_lb),
  estimatedLineSubtotalCents: Number(row.estimated_line_subtotal_cents),
  finalQuantity: row.final_quantity === null ? null : Number(row.final_quantity),
  finalWeightLb: row.final_weight_lb === null ? null : Number(row.final_weight_lb),
  finalLineSubtotalCents:
    row.final_line_subtotal_cents === null
      ? null
      : Number(row.final_line_subtotal_cents),
  createdAt: (row.created_at as Date).toISOString()
});

export const findAdminByEmail = async (email: string): Promise<AdminUser | null> => {
  const result = await query<Record<string, unknown>>(
    `SELECT id, email, password_hash, role
     FROM admin_users
     WHERE email = $1`,
    [email.toLowerCase()]
  );

  if (!result.rowCount) {
    return null;
  }

  const row = result.rows[0];
  return {
    id: row.id as string,
    email: row.email as string,
    passwordHash: row.password_hash as string,
    role: row.role as AdminRole
  };
};

export const createAdminUser = async (
  email: string,
  passwordHash: string,
  role: AdminRole
): Promise<AdminUser> => {
  const result = await query<Record<string, unknown>>(
    `INSERT INTO admin_users (email, password_hash, role)
     VALUES ($1, $2, $3)
     RETURNING id, email, password_hash, role`,
    [email.toLowerCase(), passwordHash, role]
  );
  const row = result.rows[0];
  return {
    id: row.id as string,
    email: row.email as string,
    passwordHash: row.password_hash as string,
    role: row.role as AdminRole
  };
};

export const getStoreConfig = async (): Promise<StoreConfig> => {
  const result = await query<Record<string, unknown>>(
    `SELECT timezone, open_time, close_time, slot_minutes, slot_capacity, lead_time_minutes, tax_rate_bps
     FROM pickup_slot_config
     WHERE id = TRUE`
  );

  if (!result.rowCount) {
    throw new Error("pickup_slot_config is not initialized");
  }

  const row = result.rows[0];
  return {
    timezone: row.timezone as string,
    openTime: row.open_time as string,
    closeTime: row.close_time as string,
    slotMinutes: Number(row.slot_minutes),
    slotCapacity: Number(row.slot_capacity),
    leadTimeMinutes: Number(row.lead_time_minutes),
    taxRateBps: Number(row.tax_rate_bps)
  };
};

export const updateStoreTaxRate = async (taxRateBps: number): Promise<void> => {
  await query(
    `UPDATE pickup_slot_config
     SET tax_rate_bps = $1, updated_at = NOW()
     WHERE id = TRUE`,
    [taxRateBps]
  );
};

export const listCatalogProducts = async (
  category?: ProductCategory
): Promise<DbProduct[]> => {
  const result = category
    ? await query<Record<string, unknown>>(
        `SELECT *
         FROM products
         WHERE active = TRUE AND stock_quantity > 0 AND category = $1
         ORDER BY name ASC`,
        [category]
      )
    : await query<Record<string, unknown>>(
        `SELECT *
         FROM products
         WHERE active = TRUE AND stock_quantity > 0
         ORDER BY name ASC`
      );

  return result.rows.map(mapProduct);
};

export const listAdminProducts = async (): Promise<DbProduct[]> => {
  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM products
     ORDER BY name ASC`
  );
  return result.rows.map(mapProduct);
};

export const getProductById = async (id: string): Promise<DbProduct | null> => {
  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM products
     WHERE id = $1`,
    [id]
  );

  if (!result.rowCount) {
    return null;
  }
  return mapProduct(result.rows[0]);
};

export const getProductsByIds = async (ids: string[]): Promise<DbProduct[]> => {
  if (!ids.length) {
    return [];
  }

  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM products
     WHERE id = ANY($1::uuid[])`,
    [ids]
  );

  return result.rows.map(mapProduct);
};

export const createProduct = async (
  payload: UpsertProductRequest
): Promise<DbProduct> => {
  const result = await query<Record<string, unknown>>(
    `INSERT INTO products (
      name,
      description,
      category,
      unit,
      price_cents,
      stock_quantity,
      image_key,
      image_url,
      active
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING *`,
    [
      payload.name,
      payload.description,
      payload.category,
      payload.unit,
      payload.priceCents,
      payload.stockQuantity,
      payload.imageKey,
      payload.imageUrl,
      payload.active
    ]
  );
  return mapProduct(result.rows[0]);
};

export const patchProduct = async (
  id: string,
  payload: Partial<UpsertProductRequest>
): Promise<DbProduct | null> => {
  const current = await getProductById(id);
  if (!current) {
    return null;
  }

  const merged = {
    name: payload.name ?? current.name,
    description: payload.description ?? current.description,
    category: payload.category ?? current.category,
    unit: payload.unit ?? current.unit,
    priceCents: payload.priceCents ?? current.priceCents,
    stockQuantity: payload.stockQuantity ?? current.stockQuantity,
    imageKey: payload.imageKey ?? current.imageKey,
    imageUrl: payload.imageUrl ?? current.imageUrl,
    active: payload.active ?? current.active
  };

  const result = await query<Record<string, unknown>>(
    `UPDATE products
     SET name = $2,
         description = $3,
         category = $4,
         unit = $5,
         price_cents = $6,
         stock_quantity = $7,
         image_key = $8,
         image_url = $9,
         active = $10,
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [
      id,
      merged.name,
      merged.description,
      merged.category,
      merged.unit,
      merged.priceCents,
      merged.stockQuantity,
      merged.imageKey,
      merged.imageUrl,
      merged.active
    ]
  );

  return mapProduct(result.rows[0]);
};

export const patchProductStock = async (
  id: string,
  stockQuantity: number
): Promise<DbProduct | null> => {
  const result = await query<Record<string, unknown>>(
    `UPDATE products
     SET stock_quantity = $2, updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id, stockQuantity]
  );
  if (!result.rowCount) {
    return null;
  }
  return mapProduct(result.rows[0]);
};

export const getDailySlotBookings = async (
  startIso: string,
  endIso: string
): Promise<Map<string, number>> => {
  const result = await query<Record<string, unknown>>(
    `SELECT pickup_slot_start, COUNT(*)::int AS booking_count
     FROM orders
     WHERE pickup_slot_start >= $1::timestamptz
       AND pickup_slot_start < $2::timestamptz
       AND status NOT IN ('cancelled', 'refunded')
     GROUP BY pickup_slot_start`,
    [startIso, endIso]
  );

  const map = new Map<string, number>();
  for (const row of result.rows) {
    map.set((row.pickup_slot_start as Date).toISOString(), Number(row.booking_count));
  }
  return map;
};

export const getSlotBookingsCount = async (
  client: PoolClient,
  slotStartIso: string
): Promise<number> => {
  const result = await client.query<Record<string, unknown>>(
    `SELECT COUNT(*)::int AS booking_count
     FROM orders
     WHERE pickup_slot_start = $1::timestamptz
       AND status NOT IN ('cancelled', 'refunded')`,
    [slotStartIso]
  );
  return Number(result.rows[0]?.booking_count ?? 0);
};

export interface InsertOrderInput {
  orderId: string;
  orderNumber: string;
  customerName: string;
  customerPhone: string;
  pickupSlotStartIso: string;
  pickupSlotEndIso: string;
  status: OrderStatus;
  paymentStatus: PaymentStatus;
  estimatedSubtotalCents: number;
  estimatedTaxCents: number;
  estimatedTotalCents: number;
  paymentIntentId: string | null;
  paymentClientSecret: string | null;
  paymentProvider: string;
}

export const insertOrder = async (
  client: PoolClient,
  payload: InsertOrderInput
): Promise<DbOrder> => {
  const result = await client.query<Record<string, unknown>>(
    `INSERT INTO orders (
      id,
      order_number,
      customer_name,
      customer_phone,
      pickup_slot_start,
      pickup_slot_end,
      status,
      payment_status,
      estimated_subtotal_cents,
      estimated_tax_cents,
      estimated_total_cents,
      payment_intent_id,
      payment_client_secret,
      payment_provider
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
    RETURNING *`,
    [
      payload.orderId,
      payload.orderNumber,
      payload.customerName,
      payload.customerPhone,
      payload.pickupSlotStartIso,
      payload.pickupSlotEndIso,
      payload.status,
      payload.paymentStatus,
      payload.estimatedSubtotalCents,
      payload.estimatedTaxCents,
      payload.estimatedTotalCents,
      payload.paymentIntentId,
      payload.paymentClientSecret,
      payload.paymentProvider
    ]
  );

  return mapOrder(result.rows[0]);
};

export interface InsertOrderItemInput {
  orderId: string;
  productId: string;
  productNameSnapshot: string;
  productUnitSnapshot: ProductUnit;
  productPriceCentsSnapshot: number;
  estimatedQuantity: number | null;
  estimatedWeightLb: number | null;
  estimatedLineSubtotalCents: number;
}

export const insertOrderItems = async (
  client: PoolClient,
  items: InsertOrderItemInput[]
): Promise<void> => {
  for (const item of items) {
    await client.query(
      `INSERT INTO order_items (
        order_id,
        product_id,
        product_name_snapshot,
        product_unit_snapshot,
        product_price_cents_snapshot,
        estimated_quantity,
        estimated_weight_lb,
        estimated_line_subtotal_cents
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        item.orderId,
        item.productId,
        item.productNameSnapshot,
        item.productUnitSnapshot,
        item.productPriceCentsSnapshot,
        item.estimatedQuantity,
        item.estimatedWeightLb,
        item.estimatedLineSubtotalCents
      ]
    );
  }
};

export const decrementStockForOrder = async (
  client: PoolClient,
  items: Array<{ productId: string; quantityToReserve: number }>
): Promise<void> => {
  for (const item of items) {
    const update = await client.query<{ id: string }>(
      `UPDATE products
       SET stock_quantity = stock_quantity - $2,
           updated_at = NOW()
       WHERE id = $1
         AND stock_quantity >= $2`,
      [item.productId, item.quantityToReserve]
    );

    if (update.rowCount === 0) {
      throw new Error(`Insufficient stock for product ${item.productId}`);
    }
  }
};

export const restoreStockForOrder = async (
  client: PoolClient,
  orderId: string
): Promise<void> => {
  const items = await client.query<Record<string, unknown>>(
    `SELECT product_id,
            COALESCE(final_quantity, estimated_quantity, final_weight_lb, estimated_weight_lb, 0) AS restore_amount
     FROM order_items
     WHERE order_id = $1`,
    [orderId]
  );

  for (const row of items.rows) {
    const amount = Number(row.restore_amount);
    if (amount <= 0) {
      continue;
    }
    await client.query(
      `UPDATE products
       SET stock_quantity = stock_quantity + $2,
           updated_at = NOW()
       WHERE id = $1`,
      [row.product_id, amount]
    );
  }
};

export const insertDailySequenceAndGet = async (
  client: PoolClient,
  orderDate: string
): Promise<number> => {
  const result = await client.query<{ seq: number }>(
    `INSERT INTO order_sequence (order_date, seq)
     VALUES ($1::date, 1)
     ON CONFLICT (order_date)
     DO UPDATE SET seq = order_sequence.seq + 1
     RETURNING seq`,
    [orderDate]
  );

  return Number(result.rows[0].seq);
};

export const getOrderByLookup = async (
  orderNumber: string,
  customerPhone: string
): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM orders
     WHERE order_number = $1
       AND customer_phone = $2`,
    [orderNumber, customerPhone]
  );

  if (!result.rowCount) {
    return null;
  }
  return mapOrder(result.rows[0]);
};

export const getOrderById = async (orderId: string): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM orders
     WHERE id = $1`,
    [orderId]
  );

  if (!result.rowCount) {
    return null;
  }
  return mapOrder(result.rows[0]);
};

export const listOrders = async (status?: OrderStatus): Promise<DbOrder[]> => {
  const result = status
    ? await query<Record<string, unknown>>(
        `SELECT *
         FROM orders
         WHERE status = $1
         ORDER BY created_at DESC`,
        [status]
      )
    : await query<Record<string, unknown>>(
        `SELECT *
         FROM orders
         ORDER BY created_at DESC`
      );

  return result.rows.map(mapOrder);
};

export const listOrderItems = async (orderId: string): Promise<DbOrderItem[]> => {
  const result = await query<Record<string, unknown>>(
    `SELECT *
     FROM order_items
     WHERE order_id = $1
     ORDER BY created_at ASC`,
    [orderId]
  );

  return result.rows.map(mapOrderItem);
};

export const patchOrderStatus = async (
  orderId: string,
  status: OrderStatus
): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `UPDATE orders
     SET status = $2,
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [orderId, status]
  );

  if (!result.rowCount) {
    return null;
  }
  return mapOrder(result.rows[0]);
};

export const updateOrderFinalTotals = async (
  orderId: string,
  finalSubtotalCents: number,
  finalTaxCents: number,
  finalTotalCents: number
): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `UPDATE orders
     SET final_subtotal_cents = $2,
         final_tax_cents = $3,
         final_total_cents = $4,
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [orderId, finalSubtotalCents, finalTaxCents, finalTotalCents]
  );
  if (!result.rowCount) {
    return null;
  }
  return mapOrder(result.rows[0]);
};

export const updateOrderPaymentStatus = async (
  orderId: string,
  paymentStatus: PaymentStatus
): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `UPDATE orders
     SET payment_status = $2,
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [orderId, paymentStatus]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapOrder(result.rows[0]);
};

export const setOrderPaymentFromWebhook = async (
  paymentIntentId: string,
  paymentStatus: PaymentStatus
): Promise<DbOrder | null> => {
  const result = await query<Record<string, unknown>>(
    `UPDATE orders
     SET payment_status = $2,
         updated_at = NOW()
     WHERE payment_intent_id = $1
     RETURNING *`,
    [paymentIntentId, paymentStatus]
  );

  if (!result.rowCount) {
    return null;
  }
  return mapOrder(result.rows[0]);
};

export const updateFinalizedOrderItem = async (
  orderItemId: string,
  finalQuantity: number | null,
  finalWeightLb: number | null,
  finalLineSubtotalCents: number
): Promise<void> => {
  await query(
    `UPDATE order_items
     SET final_quantity = $2,
         final_weight_lb = $3,
         final_line_subtotal_cents = $4
     WHERE id = $1`,
    [orderItemId, finalQuantity, finalWeightLb, finalLineSubtotalCents]
  );
};

export const createRefund = async (
  orderId: string,
  amountCents: number,
  reason: string,
  providerRef: string | null
): Promise<void> => {
  await query(
    `INSERT INTO refunds (order_id, amount_cents, reason, provider_ref)
     VALUES ($1, $2, $3, $4)`,
    [orderId, amountCents, reason, providerRef]
  );
};

export const getRefundedAmount = async (orderId: string): Promise<number> => {
  const result = await query<{ total_refunded: number | null }>(
    `SELECT COALESCE(SUM(amount_cents), 0)::int AS total_refunded
     FROM refunds
     WHERE order_id = $1`,
    [orderId]
  );
  return Number(result.rows[0].total_refunded ?? 0);
};

export const saveReceipt = async (orderId: string, pdfKey: string): Promise<void> => {
  await query(
    `INSERT INTO receipts (order_id, pdf_key)
     VALUES ($1, $2)
     ON CONFLICT (order_id)
     DO UPDATE SET pdf_key = EXCLUDED.pdf_key, created_at = NOW()`,
    [orderId, pdfKey]
  );
};

export const getReceiptByOrderId = async (
  orderId: string
): Promise<{ pdfKey: string } | null> => {
  const result = await query<Record<string, unknown>>(
    `SELECT pdf_key
     FROM receipts
     WHERE order_id = $1`,
    [orderId]
  );

  if (!result.rowCount) {
    return null;
  }

  return {
    pdfKey: result.rows[0].pdf_key as string
  };
};
