export const clampRefundAmount = (
  requestedCents: number,
  alreadyRefundedCents: number,
  paidCents: number
): number => {
  const remaining = Math.max(0, paidCents - alreadyRefundedCents);
  return Math.min(requestedCents, remaining);
};

export const computeTaxCents = (subtotalCents: number, taxRateBps: number): number => {
  return Math.round((subtotalCents * taxRateBps) / 10000);
};
