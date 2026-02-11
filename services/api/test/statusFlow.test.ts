import { describe, expect, it } from "vitest";
import {
  assertValidStatusTransition,
  canTransitionStatus
} from "../src/utils/statusFlow.js";

describe("status transition guards", () => {
  it("allows placed to preparing", () => {
    expect(canTransitionStatus("placed", "preparing")).toBe(true);
  });

  it("blocks cancelled to fulfilled", () => {
    expect(canTransitionStatus("cancelled", "fulfilled")).toBe(false);
  });

  it("throws on invalid transition", () => {
    expect(() => assertValidStatusTransition("fulfilled", "preparing")).toThrow(
      /Invalid status transition/
    );
  });
});
