import { beforeAll, describe, expect, it } from "vitest";
import { Pool } from "pg";
import { buildApp } from "../src/app.js";

const runIntegration = process.env.RUN_DB_INTEGRATION === "true";

const suite = runIntegration ? describe : describe.skip;

suite("API integration", () => {
  let app: Awaited<ReturnType<typeof buildApp>>;
  let pool: Pool;

  beforeAll(async () => {
    app = await buildApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });

    await pool.query(`
      INSERT INTO products (
        name, description, category, unit, price_cents, stock_quantity, image_key, image_url, active
      ) VALUES (
        'Halal Beef', 'Fresh halal beef', 'halal_meat', 'lb', 1099, 50, 'products/halal-beef.jpg',
        'https://example.com/halal-beef.jpg', TRUE
      ) ON CONFLICT DO NOTHING
    `);
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
});
