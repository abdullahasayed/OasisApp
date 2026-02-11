import type { FastifyPluginAsync } from "fastify";
import { setOrderPaymentFromWebhook } from "../db/repositories.js";

const webhookRoutes: FastifyPluginAsync = async (app) => {
  app.post("/payments/webhook", async (request, reply) => {
    const rawBody =
      typeof request.body === "string"
        ? request.body
        : JSON.stringify(request.body ?? {});

    const signature = request.headers["stripe-signature"];
    const signatureHeader =
      typeof signature === "string"
        ? signature
        : Array.isArray(signature)
          ? signature[0]
          : undefined;

    try {
      const result = await app.paymentProvider.handleWebhook(rawBody, signatureHeader);
      if (result.type === "payment_succeeded") {
        await setOrderPaymentFromWebhook(result.paymentIntentId, "paid_estimated");
      }
      return reply.send({ received: true });
    } catch (error) {
      request.log.error({ error }, "Payment webhook failed");
      return reply.code(400).send({ message: "Webhook processing failed" });
    }
  });
};

export default webhookRoutes;
