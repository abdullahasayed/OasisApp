import { DateTime } from "luxon";
import type { PickupSlot } from "@oasis/contracts";
import type { StoreConfig } from "../db/repositories.js";

const splitTime = (hhmm: string): { hour: number; minute: number } => {
  const [hour, minute] = hhmm.split(":").map((v) => Number(v));
  return { hour, minute };
};

export const buildPickupSlotsForDate = (
  date: string,
  config: StoreConfig,
  bookings: Map<string, number>,
  nowOverride?: DateTime
): PickupSlot[] => {
  const zone = config.timezone;
  const { hour: openHour, minute: openMinute } = splitTime(config.openTime);
  const { hour: closeHour, minute: closeMinute } = splitTime(config.closeTime);

  const day = DateTime.fromISO(date, { zone });
  const start = day.set({
    hour: openHour,
    minute: openMinute,
    second: 0,
    millisecond: 0
  });
  const close = day.set({
    hour: closeHour,
    minute: closeMinute,
    second: 0,
    millisecond: 0
  });

  if (!start.isValid || !close.isValid || close <= start) {
    return [];
  }

  const now = (nowOverride ?? DateTime.now()).setZone(zone);
  const leadCutoff = now.plus({ minutes: config.leadTimeMinutes });

  const slots: PickupSlot[] = [];
  let cursor = start;
  while (cursor < close) {
    const next = cursor.plus({ minutes: config.slotMinutes });
    const slotStartIso = cursor.toUTC().toISO();
    const slotEndIso = next.toUTC().toISO();

    if (!slotStartIso || !slotEndIso) {
      cursor = next;
      continue;
    }

    const booked = bookings.get(slotStartIso) ?? 0;
    const available = Math.max(0, config.slotCapacity - booked);

    if (cursor >= leadCutoff) {
      slots.push({
        startIso: slotStartIso,
        endIso: slotEndIso,
        capacity: config.slotCapacity,
        available
      });
    }

    cursor = next;
  }

  return slots;
};

export const getDayBoundaryIso = (
  date: string,
  timezone: string
): { dayStartIso: string; dayEndIso: string } => {
  const day = DateTime.fromISO(date, { zone: timezone });
  const dayStart = day.startOf("day");
  const dayEnd = day.plus({ days: 1 }).startOf("day");

  const dayStartIso = dayStart.toUTC().toISO();
  const dayEndIso = dayEnd.toUTC().toISO();

  if (!dayStartIso || !dayEndIso) {
    throw new Error("Unable to build day boundaries");
  }

  return {
    dayStartIso,
    dayEndIso
  };
};
