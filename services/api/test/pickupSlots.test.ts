import { DateTime } from "luxon";
import { describe, expect, it } from "vitest";
import { buildPickupSlotsForDate } from "../src/services/pickupSlots.js";

describe("pickup slot generation", () => {
  it("builds 1-hour slots and applies lead-time filter", () => {
    const config = {
      timezone: "America/Chicago",
      openHour: 9,
      closeHour: 12,
      slotCapacity: 5,
      leadTimeMinutes: 60
    };

    const now = DateTime.fromISO("2026-02-11T08:30:00", {
      zone: config.timezone
    });

    const slots = buildPickupSlotsForDate("2026-02-11", config, new Map(), now);

    expect(slots.length).toBe(2);
    expect(slots[0]?.available).toBe(5);

    const firstStart = slots[0]?.startIso;
    if (firstStart) {
      expect(DateTime.fromISO(firstStart).setZone(config.timezone).hour).toBe(10);
    }
  });

  it("subtracts booked capacity and applies unavailable slots", () => {
    const config = {
      timezone: "America/Chicago",
      openHour: 9,
      closeHour: 11,
      slotCapacity: 4,
      leadTimeMinutes: 0
    };

    const slotStart9 = DateTime.fromISO("2026-02-11T09:00:00", {
      zone: config.timezone
    })
      .toUTC()
      .toISO();

    const slotStart10 = DateTime.fromISO("2026-02-11T10:00:00", {
      zone: config.timezone
    })
      .toUTC()
      .toISO();

    const bookings = new Map<string, number>();
    if (slotStart9) {
      bookings.set(slotStart9, 3);
    }

    const blocked = new Set<string>();
    if (slotStart10) {
      blocked.add(slotStart10);
    }

    const now = DateTime.fromISO("2026-02-11T08:00:00", {
      zone: config.timezone
    });

    const slots = buildPickupSlotsForDate(
      "2026-02-11",
      {
        ...config,
        unavailableSlotStarts: blocked
      },
      bookings,
      now
    );

    expect(slots[0]?.available).toBe(1);
    expect(slots[1]?.available).toBe(0);
  });
});
