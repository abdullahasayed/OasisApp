import { DateTime } from "luxon";
import type { PickupSlot } from "@oasis/contracts";
import type { StoreConfig } from "../db/repositories.js";

export interface PickupSlotBuildConfig {
  timezone: string;
  slotCapacity: number;
  leadTimeMinutes: number;
  openHour: number;
  closeHour: number;
  unavailableSlotStarts?: Set<string>;
}

export const SLOT_INTERVAL_MINUTES = 60;

const clampHour = (value: number): number => {
  return Math.max(0, Math.min(24, Math.trunc(value)));
};

export const getHourlyRangeFromStoreConfig = (
  config: StoreConfig
): { openHour: number; closeHour: number } => {
  const [openHour] = config.openTime.split(":").map((v) => Number(v));
  const [closeHourRaw] = config.closeTime.split(":").map((v) => Number(v));

  const openHourSafe = clampHour(Number.isFinite(openHour) ? openHour : 9);
  let closeHourSafe = clampHour(Number.isFinite(closeHourRaw) ? closeHourRaw : 20);

  if (closeHourSafe <= openHourSafe) {
    closeHourSafe = Math.min(24, openHourSafe + 1);
  }

  return {
    openHour: openHourSafe,
    closeHour: closeHourSafe
  };
};

export const buildPickupSlotsForDate = (
  date: string,
  config: PickupSlotBuildConfig,
  bookings: Map<string, number>,
  nowOverride?: DateTime
): PickupSlot[] => {
  const zone = config.timezone;

  const day = DateTime.fromISO(date, { zone });
  const start = day.set({
    hour: config.openHour,
    minute: 0,
    second: 0,
    millisecond: 0
  });
  const close = day.set({
    hour: config.closeHour,
    minute: 0,
    second: 0,
    millisecond: 0
  });

  if (!start.isValid || !close.isValid || close <= start) {
    return [];
  }

  const now = (nowOverride ?? DateTime.now()).setZone(zone);
  const leadCutoff = now.plus({ minutes: config.leadTimeMinutes });

  const blockedStarts = config.unavailableSlotStarts ?? new Set<string>();

  const slots: PickupSlot[] = [];
  let cursor = start;
  while (cursor < close) {
    const next = cursor.plus({ minutes: SLOT_INTERVAL_MINUTES });
    const slotStartIso = cursor.toUTC().toISO();
    const slotEndIso = next.toUTC().toISO();

    if (!slotStartIso || !slotEndIso) {
      cursor = next;
      continue;
    }

    const booked = bookings.get(slotStartIso) ?? 0;
    const isUnavailable = blockedStarts.has(slotStartIso);
    const available = isUnavailable
      ? 0
      : Math.max(0, config.slotCapacity - booked);

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
