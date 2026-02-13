import { describe, expect, it } from "vitest";
import { slotShiftHoursForDelay } from "../src/utils/delayRules.js";

describe("delay slot shift rules", () => {
  it("keeps slot unchanged for 10 and 30 minute delays", () => {
    expect(slotShiftHoursForDelay(10)).toBe(0);
    expect(slotShiftHoursForDelay(30)).toBe(0);
  });

  it("moves slot forward for 60 and 90 minute delays", () => {
    expect(slotShiftHoursForDelay(60)).toBe(1);
    expect(slotShiftHoursForDelay(90)).toBe(2);
  });
});
