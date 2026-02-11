import type { DbOrder, DbOrderItem } from "../db/repositories.js";

export interface PrinterReceiptFormatter {
  buildEscPosReceipt(order: DbOrder, items: DbOrderItem[]): Buffer;
}

const money = (cents: number): string => {
  return `$${(cents / 100).toFixed(2)}`;
};

export class EpsonEscPosFormatter implements PrinterReceiptFormatter {
  buildEscPosReceipt(order: DbOrder, items: DbOrderItem[]): Buffer {
    const ESC = "\x1B";
    const GS = "\x1D";

    const lines: string[] = [];
    lines.push(`${ESC}@`); // Initialize printer.
    lines.push(`${ESC}a\x01`); // Center align.
    lines.push(`${GS}!\x11`); // Double width and height.
    lines.push("OASIS MARKETS");
    lines.push("\n");
    lines.push(`${GS}!\x00`);
    lines.push(`ORDER ${order.orderNumber}`);
    lines.push(`NAME ${order.customerName.toUpperCase()}`);
    lines.push("\n");

    lines.push(`${ESC}a\x00`); // Left align.
    lines.push("--------------------------------");
    for (const item of items) {
      const qty = item.finalWeightLb ?? item.finalQuantity ?? item.estimatedWeightLb ?? item.estimatedQuantity ?? 0;
      const total = item.finalLineSubtotalCents ?? item.estimatedLineSubtotalCents;
      lines.push(`${item.productNameSnapshot}`);
      lines.push(`  ${qty.toFixed(2)} ${item.productUnitSnapshot}  ${money(total)}`);
    }
    lines.push("--------------------------------");
    lines.push(`EST TOTAL: ${money(order.estimatedTotalCents)}`);
    if (order.finalTotalCents !== null) {
      lines.push(`FINAL TOTAL: ${money(order.finalTotalCents)}`);
    }
    lines.push(`STATUS: ${order.status.toUpperCase()}`);
    lines.push(`PICKUP: ${order.pickupSlotStartIso}`);
    lines.push("\n\n");
    lines.push(`${GS}V\x00`); // Full cut.

    return Buffer.from(lines.join("\n"), "binary");
  }
}
