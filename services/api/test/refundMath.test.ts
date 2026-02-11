import { describe, expect, it } from "vitest";
import { clampRefundAmount, computeTaxCents } from "../src/utils/refundMath.js";

describe("refund math", () => {
  it("caps refund at remaining paid amount", () => {
    expect(clampRefundAmount(900, 300, 1000)).toBe(700);
  });

  it("returns zero when fully refunded", () => {
    expect(clampRefundAmount(100, 1000, 1000)).toBe(0);
  });

  it("computes tax from bps", () => {
    expect(computeTaxCents(1000, 825)).toBe(83);
  });
});
