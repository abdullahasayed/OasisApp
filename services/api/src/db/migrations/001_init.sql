CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('superadmin', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL CHECK (category IN ('halal_meat', 'fruits', 'vegetables', 'grocery_other')),
  unit TEXT NOT NULL CHECK (unit IN ('each', 'lb')),
  price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
  stock_quantity NUMERIC(10,3) NOT NULL CHECK (stock_quantity >= 0),
  image_key TEXT NOT NULL,
  image_url TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pickup_slot_config (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE,
  timezone TEXT NOT NULL,
  open_time TEXT NOT NULL,
  close_time TEXT NOT NULL,
  slot_minutes INTEGER NOT NULL CHECK (slot_minutes > 0),
  slot_capacity INTEGER NOT NULL CHECK (slot_capacity > 0),
  lead_time_minutes INTEGER NOT NULL CHECK (lead_time_minutes >= 0),
  tax_rate_bps INTEGER NOT NULL CHECK (tax_rate_bps >= 0 AND tax_rate_bps <= 10000),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (id = TRUE)
);

CREATE TABLE IF NOT EXISTS order_sequence (
  order_date DATE PRIMARY KEY,
  seq INTEGER NOT NULL CHECK (seq > 0)
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  pickup_slot_start TIMESTAMPTZ NOT NULL,
  pickup_slot_end TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('placed', 'preparing', 'ready', 'fulfilled', 'delayed', 'cancelled', 'refunded')),
  payment_status TEXT NOT NULL CHECK (payment_status IN ('pending', 'paid_estimated', 'partially_refunded', 'fully_refunded')),
  estimated_subtotal_cents INTEGER NOT NULL CHECK (estimated_subtotal_cents >= 0),
  estimated_tax_cents INTEGER NOT NULL CHECK (estimated_tax_cents >= 0),
  estimated_total_cents INTEGER NOT NULL CHECK (estimated_total_cents >= 0),
  final_subtotal_cents INTEGER,
  final_tax_cents INTEGER,
  final_total_cents INTEGER,
  payment_intent_id TEXT,
  payment_client_secret TEXT,
  payment_provider TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_pickup_slot_start ON orders (pickup_slot_start);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);

CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  product_name_snapshot TEXT NOT NULL,
  product_unit_snapshot TEXT NOT NULL CHECK (product_unit_snapshot IN ('each', 'lb')),
  product_price_cents_snapshot INTEGER NOT NULL CHECK (product_price_cents_snapshot >= 0),
  estimated_quantity NUMERIC(10,3),
  estimated_weight_lb NUMERIC(10,3),
  estimated_line_subtotal_cents INTEGER NOT NULL CHECK (estimated_line_subtotal_cents >= 0),
  final_quantity NUMERIC(10,3),
  final_weight_lb NUMERIC(10,3),
  final_line_subtotal_cents INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
  reason TEXT NOT NULL,
  provider_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);

CREATE TABLE IF NOT EXISTS receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  pdf_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO pickup_slot_config (
  id,
  timezone,
  open_time,
  close_time,
  slot_minutes,
  slot_capacity,
  lead_time_minutes,
  tax_rate_bps
)
VALUES (TRUE, 'America/Chicago', '09:00', '20:00', 30, 20, 60, 825)
ON CONFLICT (id) DO NOTHING;
