import Stripe from "stripe";
import type { FastifyBaseLogger } from "fastify";
import { getConfig } from "../config.js";

export interface PaymentIntentRequest {
  orderId: string;
  orderNumber: string;
  amountCents: number;
  currency: string;
  customerName: string;
  customerPhone: string;
}

export interface PaymentIntentResult {
  paymentIntentId: string;
  clientSecret: string;
}

export interface RefundResult {
  refundId: string;
  amountCents: number;
}

export type WebhookProcessingResult =
  | {
      type: "payment_succeeded";
      paymentIntentId: string;
    }
  | {
      type: "ignored";
    };

export interface PaymentProvider {
  readonly providerName: string;
  createPaymentIntent(input: PaymentIntentRequest): Promise<PaymentIntentResult>;
  refund(
    paymentIntentId: string,
    amountCents: number,
    reason: string
  ): Promise<RefundResult>;
  handleWebhook(rawBody: string, signature?: string): Promise<WebhookProcessingResult>;
}

class MockPaymentProvider implements PaymentProvider {
  readonly providerName = "mock";

  async createPaymentIntent(input: PaymentIntentRequest): Promise<PaymentIntentResult> {
    return {
      paymentIntentId: `pi_mock_${input.orderId.replace(/-/g, "")}`,
      clientSecret: `pi_mock_secret_${input.orderNumber}`
    };
  }

  async refund(
    paymentIntentId: string,
    amountCents: number,
    _reason: string
  ): Promise<RefundResult> {
    return {
      refundId: `re_mock_${paymentIntentId}`,
      amountCents
    };
  }

  async handleWebhook(_rawBody: string): Promise<WebhookProcessingResult> {
    return { type: "ignored" };
  }
}

class StripePaymentProvider implements PaymentProvider {
  readonly providerName = "stripe";
  private readonly stripe: Stripe;
  private readonly webhookSecret: string;

  constructor(stripe: Stripe, webhookSecret: string) {
    this.stripe = stripe;
    this.webhookSecret = webhookSecret;
  }

  async createPaymentIntent(input: PaymentIntentRequest): Promise<PaymentIntentResult> {
    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: input.amountCents,
      currency: input.currency,
      metadata: {
        orderId: input.orderId,
        orderNumber: input.orderNumber,
        customerName: input.customerName,
        customerPhone: input.customerPhone
      },
      automatic_payment_methods: {
        enabled: true
      }
    });

    if (!paymentIntent.client_secret) {
      throw new Error("Stripe payment intent did not return client_secret");
    }

    return {
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret
    };
  }

  async refund(
    paymentIntentId: string,
    amountCents: number,
    reason: string
  ): Promise<RefundResult> {
    const refund = await this.stripe.refunds.create({
      payment_intent: paymentIntentId,
      amount: amountCents,
      metadata: {
        reason
      }
    });

    return {
      refundId: refund.id,
      amountCents: refund.amount
    };
  }

  async handleWebhook(rawBody: string, signature?: string): Promise<WebhookProcessingResult> {
    if (!signature) {
      throw new Error("Missing Stripe-Signature header");
    }

    const event = this.stripe.webhooks.constructEvent(
      rawBody,
      signature,
      this.webhookSecret
    );

    if (event.type === "payment_intent.succeeded") {
      const intent = event.data.object as Stripe.PaymentIntent;
      return {
        type: "payment_succeeded",
        paymentIntentId: intent.id
      };
    }

    return { type: "ignored" };
  }
}

export const buildPaymentProvider = (logger: FastifyBaseLogger): PaymentProvider => {
  const config = getConfig();

  if (
    config.PAYMENT_PROVIDER === "stripe" &&
    config.STRIPE_SECRET_KEY &&
    config.STRIPE_WEBHOOK_SECRET
  ) {
    const stripe = new Stripe(config.STRIPE_SECRET_KEY, {
      apiVersion: "2024-12-18.acacia"
    });
    return new StripePaymentProvider(stripe, config.STRIPE_WEBHOOK_SECRET);
  }

  logger.warn(
    "Using mock payment provider. Configure STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET for Stripe."
  );
  return new MockPaymentProvider();
};
