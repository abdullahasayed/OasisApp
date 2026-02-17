# Oasis API

Fastify service for Oasis Markets pickup orders.

## Endpoints
Base prefix: `/v1`

### Shopper
- `GET /catalog?category=...&q=...&limit=...`
- `GET /products/:id`
- `GET /pickup-slots?date=YYYY-MM-DD`
- `POST /orders`
- `GET /orders/lookup?orderNumber=...&phone=...`
- `GET /orders/:id/receipt`

### Admin
- `POST /admin/auth/login`
- `POST /admin/users` (superadmin)
- `GET /admin/products`
- `POST /admin/products`
- `PATCH /admin/products/:id`
- `PATCH /admin/products/:id/stock`
- `GET /admin/pickup-availability`
- `PUT /admin/pickup-availability/:date/range`
- `PUT /admin/pickup-slots/:slotStartIso/unavailable`
- `GET /admin/orders?status=...`
- `PATCH /admin/orders/:id/status`
- `POST /admin/orders/:id/delay`
- `POST /admin/orders/:id/finalize`
- `POST /admin/orders/:id/refund`
- `POST /admin/orders/:id/fulfill`
- `GET /admin/orders/:id/receipt/escpos`

### Webhooks
- `POST /payments/webhook`

## Run
1. `cp .env.example .env`
2. Run infra from repo root: `docker compose -f infra/docker-compose.yml up -d`
3. `pnpm migrate`
4. `pnpm dev`

## Seeded superadmin
On API startup, the service ensures a superadmin account exists using:
- `SUPERADMIN_EMAIL`
- `SUPERADMIN_PASSWORD`

## Catalog Search
- `q`: optional search text (trimmed, max 80 chars).
- `limit`: optional result cap (1-200, default 100).
- When `q` is provided, search runs across all categories and ignores category filtering for the base query.

## Inventory CSV Roundtrip (Excel)
- Export inventory to CSV:
  - `npm run inventory:export --workspace @oasis/api -- --out ./inventory.csv`
- Validate import without writes:
  - `npm run inventory:import --workspace @oasis/api -- --in ./inventory.csv --dry-run`
- Import with upsert-by-id:
  - `npm run inventory:import --workspace @oasis/api -- --in ./inventory.csv`

CSV header (exact order):
- `id,name,description,category,unit,price_cents,stock_quantity,image_key,image_url,active,search_keywords`

`search_keywords` is stored as pipe-delimited values (for example: `ribeye|steak|beef cut`), normalized on import, and never exposed in shopper/admin API responses.
