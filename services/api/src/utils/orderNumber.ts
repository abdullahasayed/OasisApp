export const buildOrderNumber = (date: Date, sequence: number): string => {
  const yyyy = String(date.getUTCFullYear());
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  const seq = String(sequence).padStart(4, "0");
  return `OM-${yyyy}${mm}${dd}-${seq}`;
};
