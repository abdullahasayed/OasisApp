CREATE TABLE IF NOT EXISTS pickup_day_ranges (
  service_date DATE PRIMARY KEY,
  open_hour SMALLINT NOT NULL CHECK (open_hour BETWEEN 0 AND 23),
  close_hour SMALLINT NOT NULL CHECK (close_hour BETWEEN 1 AND 24 AND close_hour > open_hour),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pickup_slot_unavailable (
  slot_start TIMESTAMPTZ PRIMARY KEY,
  slot_end TIMESTAMPTZ NOT NULL,
  service_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pickup_slot_unavailable_service_date
  ON pickup_slot_unavailable (service_date);

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS requested_pickup_slot_start TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS requested_pickup_slot_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS estimated_pickup_start TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS estimated_pickup_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS total_delay_minutes INTEGER NOT NULL DEFAULT 0 CHECK (total_delay_minutes >= 0);

UPDATE orders
SET requested_pickup_slot_start = COALESCE(requested_pickup_slot_start, pickup_slot_start),
    requested_pickup_slot_end = COALESCE(requested_pickup_slot_end, pickup_slot_end),
    estimated_pickup_start = COALESCE(estimated_pickup_start, pickup_slot_start),
    estimated_pickup_end = COALESCE(estimated_pickup_end, pickup_slot_end);

ALTER TABLE orders
  ALTER COLUMN requested_pickup_slot_start SET NOT NULL,
  ALTER COLUMN requested_pickup_slot_end SET NOT NULL,
  ALTER COLUMN estimated_pickup_start SET NOT NULL,
  ALTER COLUMN estimated_pickup_end SET NOT NULL;

UPDATE pickup_slot_config
SET slot_minutes = 60,
    updated_at = NOW()
WHERE id = TRUE;
