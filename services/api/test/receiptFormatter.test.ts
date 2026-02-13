import { describe, expect, it } from "vitest";
import { EpsonEscPosFormatter } from "../src/adapters/printer.js";
import { buildCustomerReceiptPdf } from "../src/services/receipts.js";

describe("receipt rendering", () => {
  const order = {
    id: "11111111-1111-1111-1111-111111111111",
    orderNumber: "OM-20260211-0042",
    customerName: "Jane Doe",
    customerPhone: "+15551231234",
    pickupSlotStartIso: "2026-02-11T17:00:00.000Z",
    pickupSlotEndIso: "2026-02-11T17:30:00.000Z",
    requestedPickupSlotStartIso: "2026-02-11T17:00:00.000Z",
    requestedPickupSlotEndIso: "2026-02-11T17:30:00.000Z",
    estimatedPickupStartIso: "2026-02-11T17:00:00.000Z",
    estimatedPickupEndIso: "2026-02-11T18:00:00.000Z",
    totalDelayMinutes: 0,
    status: "fulfilled",
    paymentStatus: "paid_estimated",
    estimatedSubtotalCents: 2500,
    estimatedTaxCents: 206,
    estimatedTotalCents: 2706,
    finalSubtotalCents: 2400,
    finalTaxCents: 198,
    finalTotalCents: 2598,
    paymentIntentId: "pi_123",
    paymentClientSecret: "secret",
    paymentProvider: "stripe",
    createdAt: "2026-02-11T16:00:00.000Z",
    updatedAt: "2026-02-11T16:30:00.000Z"
  } as const;

  const items = [
    {
      id: "22222222-2222-2222-2222-222222222222",
      orderId: order.id,
      productId: "33333333-3333-3333-3333-333333333333",
      productNameSnapshot: "Halal Lamb",
      productUnitSnapshot: "lb",
      productPriceCentsSnapshot: 1200,
      estimatedQuantity: null,
      estimatedWeightLb: 2,
      estimatedLineSubtotalCents: 2400,
      finalQuantity: null,
      finalWeightLb: 2,
      finalLineSubtotalCents: 2400,
      createdAt: "2026-02-11T16:00:00.000Z"
    }
  ] as const;

  it("includes order number in ESC/POS payload", () => {
    const formatter = new EpsonEscPosFormatter();
    const payload = formatter.buildEscPosReceipt(order, [...items]);
    const text = payload.toString("binary");
    expect(text).toContain("OM-20260211-0042");
    expect(text).toContain("JANE DOE");
  });

  it("generates non-empty customer PDF", async () => {
    const pdf = await buildCustomerReceiptPdf(order, [...items]);
    expect(pdf.length).toBeGreaterThan(1000);
    expect(pdf.slice(0, 4).toString()).toBe("%PDF");
  });
});
