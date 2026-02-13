import { randomUUID } from "node:crypto";
import { DateTime } from "luxon";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { Pool } from "pg";

const runIntegration = process.env.RUN_DB_INTEGRATION === "true";

const suite = runIntegration ? describe : describe.skip;

interface TestSlot {
  dateKey: string;
  startIso: string;
  endIso: string;
}

const hourFromTime = (value: string): number => {
  return Number(value.split(":")[0] ?? "0");
};

suite("API integration", () => {
  let app: FastifyInstance;
  let pool: Pool;
  let adminToken = "";
  let timezone = "America/Chicago";
  let defaultOpenHour = 9;
  let defaultCloseHour = 20;
  let productId = "";

  const authHeaders = (): Record<string, string> => ({
    authorization: `Bearer ${adminToken}`
  });

  const buildTomorrowSlot = (hour: number): TestSlot => {
    const tomorrow = DateTime.now().setZone(timezone).startOf("day").plus({ days: 1 });
    const start = tomorrow.set({
      hour,
      minute: 0,
      second: 0,
      millisecond: 0
    });
    const end = start.plus({ hours: 1 });
    const dateKey = tomorrow.toISODate();
    const startIso = start.toUTC().toISO();
    const endIso = end.toUTC().toISO();

    if (!dateKey || !startIso || !endIso) {
      throw new Error("Failed to build test slot");
    }

    return { dateKey, startIso, endIso };
  };

  const insertOrder = async (slot: TestSlot, status = "placed"): Promise<string> => {
    const orderId = randomUUID();
    const orderNumber = `IT-${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;
    const paymentIntentId = `pi_mock_${orderId.replace(/-/g, "")}`;
    const paymentClientSecret = `pi_mock_secret_${orderNumber}`;

    await pool.query(
      `INSERT INTO orders (
        id,
        order_number,
        customer_name,
        customer_phone,
        pickup_slot_start,
        pickup_slot_end,
        requested_pickup_slot_start,
        requested_pickup_slot_end,
        estimated_pickup_start,
        estimated_pickup_end,
        total_delay_minutes,
        status,
        payment_status,
        estimated_subtotal_cents,
        estimated_tax_cents,
        estimated_total_cents,
        payment_intent_id,
        payment_client_secret,
        payment_provider
      )
      VALUES (
        $1::uuid,
        $2,
        'Integration Tester',
        '+15555550001',
        $3::timestamptz,
        $4::timestamptz,
        $3::timestamptz,
        $4::timestamptz,
        $3::timestamptz,
        $4::timestamptz,
        0,
        $5,
        'pending',
        500,
        41,
        541,
        $6,
        $7,
        'mock'
      )`,
      [
        orderId,
        orderNumber,
        slot.startIso,
        slot.endIso,
        status,
        paymentIntentId,
        paymentClientSecret
      ]
    );

    return orderId;
  };

  const setDayRange = async (date: string, openHour: number, closeHour: number): Promise<void> => {
    const response = await app.inject({
      method: "PUT",
      url: `/v1/admin/pickup-availability/${date}/range`,
      headers: authHeaders(),
      payload: {
        openHour,
        closeHour
      }
    });

    expect(response.statusCode).toBe(200);
  };

  beforeAll(async () => {
    const { buildApp } = await import("../src/app.js");
    app = await buildApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });

    const configResult = await pool.query<{
      timezone: string;
      open_time: string;
      close_time: string;
    }>(
      `SELECT timezone, open_time, close_time
       FROM pickup_slot_config
       WHERE id = TRUE`
    );
    if (!configResult.rowCount) {
      throw new Error("pickup_slot_config row is required for integration tests");
    }
    timezone = configResult.rows[0].timezone;
    defaultOpenHour = hourFromTime(configResult.rows[0].open_time);
    defaultCloseHour = hourFromTime(configResult.rows[0].close_time);

    const productResult = await pool.query<{ id: string }>(
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
      ) VALUES (
        $1,
        'Integration test product',
        'grocery_other',
        'each',
        499,
        500,
        'products/integration-product.jpg',
        'https://example.com/integration-product.jpg',
        TRUE
      ) RETURNING id`,
      [`Integration Product ${Date.now()}`]
    );
    productId = productResult.rows[0].id;

    const email = process.env.SUPERADMIN_EMAIL;
    const password = process.env.SUPERADMIN_PASSWORD;
    if (!email || !password) {
      throw new Error("SUPERADMIN_EMAIL and SUPERADMIN_PASSWORD must be set");
    }

    const login = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email, password }
    });

    expect(login.statusCode).toBe(200);
    const body = login.json() as { accessToken: string };
    adminToken = body.accessToken;

    await pool.query(`
      INSERT INTO products (
        name, description, category, unit, price_cents, stock_quantity, image_key, image_url, active
      ) VALUES (
        'Halal Beef', 'Fresh halal beef', 'halal_meat', 'lb', 1099, 50, 'products/halal-beef.jpg',
        'https://example.com/halal-beef.jpg', TRUE
      ) ON CONFLICT DO NOTHING
    `);
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  it("returns catalog", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/catalog"
    });

    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(Array.isArray(body.products)).toBe(true);
  });

  it("returns pickup slots", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/pickup-slots?date=2026-02-11"
    });

    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(Array.isArray(body.slots)).toBe(true);
  });

  it("applies cumulative delays and slot shift rules", async () => {
    const slot = buildTomorrowSlot(defaultOpenHour + 1);
    const orderId = await insertOrder(slot);

    const firstDelay = await app.inject({
      method: "POST",
      url: `/v1/admin/orders/${orderId}/delay`,
      headers: authHeaders(),
      payload: { delayMinutes: 60 }
    });

    expect(firstDelay.statusCode).toBe(200);
    const delayedOnce = firstDelay.json() as {
      status: string;
      totalDelayMinutes: number;
      pickupSlotStartIso: string;
      estimatedPickupStartIso: string;
    };
    expect(delayedOnce.status).toBe("delayed");
    expect(delayedOnce.totalDelayMinutes).toBe(60);
    expect(DateTime.fromISO(delayedOnce.pickupSlotStartIso).toMillis()).toBe(
      DateTime.fromISO(slot.startIso).plus({ hours: 1 }).toMillis()
    );
    expect(DateTime.fromISO(delayedOnce.estimatedPickupStartIso).toMillis()).toBe(
      DateTime.fromISO(slot.startIso).plus({ minutes: 60 }).toMillis()
    );

    const secondDelay = await app.inject({
      method: "POST",
      url: `/v1/admin/orders/${orderId}/delay`,
      headers: authHeaders(),
      payload: { delayMinutes: 30 }
    });

    expect(secondDelay.statusCode).toBe(200);
    const delayedTwice = secondDelay.json() as {
      totalDelayMinutes: number;
      pickupSlotStartIso: string;
      estimatedPickupStartIso: string;
    };
    expect(delayedTwice.totalDelayMinutes).toBe(90);
    expect(DateTime.fromISO(delayedTwice.pickupSlotStartIso).toMillis()).toBe(
      DateTime.fromISO(slot.startIso).plus({ hours: 1 }).toMillis()
    );
    expect(DateTime.fromISO(delayedTwice.estimatedPickupStartIso).toMillis()).toBe(
      DateTime.fromISO(slot.startIso).plus({ minutes: 90 }).toMillis()
    );
  });

  it("keeps existing orders when day range narrows while restricting new-slot list", async () => {
    const outsideHour = Math.min(defaultCloseHour - 1, defaultOpenHour + 2);
    const narrowedCloseHour = Math.max(defaultOpenHour + 1, outsideHour);
    const slot = buildTomorrowSlot(outsideHour);
    const orderId = await insertOrder(slot);

    await setDayRange(slot.dateKey, defaultOpenHour, narrowedCloseHour);
    try {
      const existing = await pool.query<{ id: string }>(
        `SELECT id FROM orders WHERE id = $1::uuid`,
        [orderId]
      );
      expect(existing.rowCount).toBe(1);

      const slotsResponse = await app.inject({
        method: "GET",
        url: `/v1/pickup-slots?date=${slot.dateKey}`
      });
      expect(slotsResponse.statusCode).toBe(200);
      const slotsBody = slotsResponse.json() as { slots: Array<{ startIso: string }> };
      expect(slotsBody.slots.some((value) => value.startIso === slot.startIso)).toBe(false);
    } finally {
      await setDayRange(slot.dateKey, defaultOpenHour, defaultCloseHour);
    }
  });

  it("blocks new orders for unavailable slots while keeping existing orders", async () => {
    const slot = buildTomorrowSlot(defaultOpenHour + 2);
    const existingOrderId = await insertOrder(slot);

    const blockResponse = await app.inject({
      method: "PUT",
      url: `/v1/admin/pickup-slots/${encodeURIComponent(slot.startIso)}/unavailable`,
      headers: authHeaders(),
      payload: { unavailable: true }
    });
    expect(blockResponse.statusCode).toBe(200);

    try {
      const existing = await pool.query<{ id: string }>(
        `SELECT id FROM orders WHERE id = $1::uuid`,
        [existingOrderId]
      );
      expect(existing.rowCount).toBe(1);

      const createResponse = await app.inject({
        method: "POST",
        url: "/v1/orders",
        payload: {
          customerName: "Blocked Slot Test",
          customerPhone: "+15555550002",
          pickupSlotStartIso: slot.startIso,
          items: [{ productId, quantity: 1 }]
        }
      });
      expect(createResponse.statusCode).toBe(409);
    } finally {
      await app.inject({
        method: "PUT",
        url: `/v1/admin/pickup-slots/${encodeURIComponent(slot.startIso)}/unavailable`,
        headers: authHeaders(),
        payload: { unavailable: false }
      });
    }
  });
});
