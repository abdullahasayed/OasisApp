import type { OrderStatus } from "@oasis/contracts";

const allowedTransitions: Record<OrderStatus, OrderStatus[]> = {
  placed: ["preparing", "delayed", "cancelled", "refunded"],
  preparing: ["ready", "delayed", "cancelled", "refunded"],
  ready: ["fulfilled", "delayed", "cancelled", "refunded"],
  fulfilled: ["refunded"],
  delayed: ["preparing", "ready", "cancelled", "refunded"],
  cancelled: [],
  refunded: []
};

export const canTransitionStatus = (
  current: OrderStatus,
  next: OrderStatus
): boolean => {
  if (current === next) {
    return true;
  }
  return allowedTransitions[current].includes(next);
};

export const assertValidStatusTransition = (
  current: OrderStatus,
  next: OrderStatus
): void => {
  if (!canTransitionStatus(current, next)) {
    throw new Error(`Invalid status transition: ${current} -> ${next}`);
  }
};
