# Oasis Markets MVP

Monorepo scaffold for the Oasis Markets pickup-ordering MVP.

## Structure
- `apps/ios`: SwiftUI iOS app (shopper + admin in one app)
- `services/api`: Fastify + Postgres backend
- `packages/contracts`: Shared TypeScript contracts/schemas
- `infra/docker-compose.yml`: Postgres + MinIO for local development

## Core MVP capabilities implemented
- Shopper: catalog, cart, checkout request, pickup-slot selection, order lookup, receipt retrieval
- Admin: login, inventory CRUD, order status changes, finalize, refund, fulfill
- Payment adapter architecture with Stripe and mock provider
- Storage adapter architecture with S3-compatible and local provider
- Epson ESC/POS payload formatter for receipt printing
- Order number format: `OM-YYYYMMDD-####`
- Postgres migration with required tables and constraints

## Local setup
1. Start infra:
   - `docker compose -f infra/docker-compose.yml up -d`
2. Configure backend env:
   - `cp services/api/.env.example services/api/.env`
3. Install dependencies from repo root (using your package manager):
   - `pnpm install` (preferred) or `npm install --workspaces`
4. Run migrations:
   - `pnpm --filter @oasis/api migrate`
5. Start API:
   - `pnpm --filter @oasis/api dev`

## iOS setup
- See `apps/ios/README.md`.

## Important notes
- This repo is scaffolded for fast MVP delivery and extension.
- Stripe and Epson SDK UI wiring on iOS is protocol-based and intentionally adapter-ready.
- Backend Stripe webhook endpoint verifies signatures when Stripe keys are configured.
