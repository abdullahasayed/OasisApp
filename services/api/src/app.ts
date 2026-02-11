import Fastify, { type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import sensible from "@fastify/sensible";
import fastifyRawBody from "fastify-raw-body";
import { getConfig } from "./config.js";
import authPlugin from "./plugins/auth.js";
import { buildPaymentProvider } from "./adapters/payment.js";
import { buildStorageProvider } from "./adapters/storage.js";
import { EpsonEscPosFormatter } from "./adapters/printer.js";
import shopperRoutes from "./routes/shopper.js";
import adminRoutes from "./routes/admin.js";
import webhookRoutes from "./routes/webhooks.js";
import { ensureSeedSuperadmin } from "./auth/adminAuth.js";

export const buildApp = async (): Promise<FastifyInstance> => {
  const config = getConfig();

  const app = Fastify({
    logger: true,
    bodyLimit: 2 * 1024 * 1024
  });

  app.decorate("config", config);
  app.decorate("paymentProvider", buildPaymentProvider(app.log));
  app.decorate("storageProvider", buildStorageProvider());
  app.decorate("printerFormatter", new EpsonEscPosFormatter());

  await app.register(cors, {
    origin: true
  });
  await app.register(sensible);
  await app.register(fastifyRawBody, {
    field: "rawBody",
    global: false,
    encoding: "utf8",
    runFirst: true,
    routes: ["/v1/payments/webhook"]
  });
  await app.register(authPlugin);

  app.get("/health", async () => ({ status: "ok" }));

  await app.register(
    async (v1) => {
      await v1.register(shopperRoutes);
      await v1.register(adminRoutes);
      await v1.register(webhookRoutes);
    },
    { prefix: "/v1" }
  );

  await ensureSeedSuperadmin();

  return app;
};
