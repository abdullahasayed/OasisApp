import "fastify";
import type { AdminRole } from "@oasis/contracts";

export interface AdminJwtPayload {
  adminId: string;
  role: AdminRole;
}

declare module "fastify" {
  interface FastifyInstance {
    config: import("../config.js").AppConfig;
    authenticateAdmin: import("fastify").preHandlerHookHandler;
    authorizeSuperadmin: import("fastify").preHandlerHookHandler;
    paymentProvider: import("../adapters/payment.js").PaymentProvider;
    storageProvider: import("../adapters/storage.js").StorageProvider;
    printerFormatter: import("../adapters/printer.js").PrinterReceiptFormatter;
  }

  interface FastifyRequest {
    admin?: AdminJwtPayload;
  }
}
