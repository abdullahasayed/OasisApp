import type { ProductUnit } from "@oasis/contracts";
import { computeTaxCents } from "../utils/refundMath.js";

export interface PricedLineInput {
  productId: string;
  unit: ProductUnit;
  priceCents: number;
  requestedQuantity: number;
  requestedWeightLb?: number;
}

export interface EstimatedLine {
  productId: string;
  estimatedQuantity: number | null;
  estimatedWeightLb: number | null;
  estimatedLineSubtotalCents: number;
  quantityToReserve: number;
}

export const buildEstimatedLines = (
  lines: PricedLineInput[]
): {
  estimatedLines: EstimatedLine[];
  estimatedSubtotalCents: number;
} => {
  const estimatedLines = lines.map((line) => {
    if (line.unit === "lb") {
      const weight = line.requestedWeightLb ?? line.requestedQuantity;
      const subtotal = Math.round(line.priceCents * weight);
      return {
        productId: line.productId,
        estimatedQuantity: null,
        estimatedWeightLb: weight,
        estimatedLineSubtotalCents: subtotal,
        quantityToReserve: weight
      } satisfies EstimatedLine;
    }

    const quantity = line.requestedQuantity;
    const subtotal = Math.round(line.priceCents * quantity);
    return {
      productId: line.productId,
      estimatedQuantity: quantity,
      estimatedWeightLb: null,
      estimatedLineSubtotalCents: subtotal,
      quantityToReserve: quantity
    } satisfies EstimatedLine;
  });

  const estimatedSubtotalCents = estimatedLines.reduce(
    (sum, line) => sum + line.estimatedLineSubtotalCents,
    0
  );

  return { estimatedLines, estimatedSubtotalCents };
};

export const buildTotals = (
  subtotalCents: number,
  taxRateBps: number
): { subtotalCents: number; taxCents: number; totalCents: number } => {
  const taxCents = computeTaxCents(subtotalCents, taxRateBps);
  return {
    subtotalCents,
    taxCents,
    totalCents: subtotalCents + taxCents
  };
};
