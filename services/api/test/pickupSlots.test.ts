import { DateTime } from "luxon";
import { describe, expect, it } from "vitest";
import { buildPickupSlotsForDate } from "../src/services/pickupSlots.js";

describe("pickup slot generation", () => {
  it("builds 30-minute slots and applies lead-time filter", () => {
    const config = {
      timezone: "America/Chicago",
      openTime: "09:00",
      closeTime: "11:00",
      slotMinutes: 30,
      slotCapacity: 5,
      leadTimeMinutes: 60,
      taxRateBps: 825
    };

    const now = DateTime.fromISO("2026-02-11T08:30:00", {
      zone: config.timezone
    });

    const slots = buildPickupSlotsForDate("2026-02-11", config, new Map(), now);

    expect(slots.length).toBe(3);
    expect(slots[0]?.available).toBe(5);
  });

  it("subtracts booked capacity", () => {
    const config = {
      timezone: "America/Chicago",
      openTime: "09:00",
      closeTime: "10:00",
      slotMinutes: 30,
      slotCapacity: 4,
      leadTimeMinutes: 0,
      taxRateBps: 825
    };

    const slotStart = DateTime.fromISO("2026-02-11T09:00:00", {
      zone: config.timezone
    })
      .toUTC()
      .toISO();

    const bookings = new Map<string, number>();
    if (slotStart) {
      bookings.set(slotStart, 3);
    }

    const slots = buildPickupSlotsForDate("2026-02-11", config, bookings);
    expect(slots[0]?.available).toBe(1);
  });
});
