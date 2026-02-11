export const normalizePhone = (value: string): string => {
  return value.replace(/[^\d+]/g, "");
};
