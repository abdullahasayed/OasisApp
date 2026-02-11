import { describe, expect, it } from "vitest";
import { buildOrderNumber } from "../src/utils/orderNumber.js";

describe("buildOrderNumber", () => {
  it("formats order number with OM prefix and padded sequence", () => {
    const date = new Date("2026-02-11T12:00:00.000Z");
    expect(buildOrderNumber(date, 42)).toBe("OM-20260211-0042");
  });

  it("supports larger sequences", () => {
    const date = new Date("2026-02-11T12:00:00.000Z");
    expect(buildOrderNumber(date, 12345)).toBe("OM-20260211-12345");
  });
});
