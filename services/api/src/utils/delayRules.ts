import type { DelayMinutes } from "@oasis/contracts";

export const slotShiftHoursForDelay = (delayMinutes: DelayMinutes): number => {
  if (delayMinutes === 60) {
    return 1;
  }
  if (delayMinutes === 90) {
    return 2;
  }
  return 0;
};
