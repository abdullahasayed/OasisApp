import PDFDocument from "pdfkit";
import type { DbOrder, DbOrderItem } from "../db/repositories.js";

const money = (cents: number): string => {
  return `$${(cents / 100).toFixed(2)}`;
};

export const buildCustomerReceiptPdf = async (
  order: DbOrder,
  items: DbOrderItem[]
): Promise<Buffer> => {
  const doc = new PDFDocument({
    size: "LETTER",
    margin: 48
  });

  const chunks: Buffer[] = [];
  doc.on("data", (chunk) => chunks.push(Buffer.from(chunk)));

  const done = new Promise<Buffer>((resolve, reject) => {
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);
  });

  doc.fontSize(24).text("OASIS MARKETS", { align: "center" });
  doc.moveDown(0.5);

  doc.fontSize(20).text(`ORDER ${order.orderNumber}`, {
    align: "center"
  });
  doc.fontSize(18).text(order.customerName.toUpperCase(), { align: "center" });

  doc.moveDown();
  doc.fontSize(12).text(`Order ID: ${order.id}`);
  doc.text(`Pickup Slot: ${order.pickupSlotStartIso} - ${order.pickupSlotEndIso}`);
  doc.text(`Status: ${order.status.toUpperCase()}`);
  doc.moveDown();

  doc.fontSize(14).text("Items", { underline: true });
  doc.moveDown(0.25);

  for (const item of items) {
    const quantityOrWeight =
      item.finalWeightLb ??
      item.finalQuantity ??
      item.estimatedWeightLb ??
      item.estimatedQuantity ??
      0;
    const lineTotal = item.finalLineSubtotalCents ?? item.estimatedLineSubtotalCents;
    doc
      .fontSize(12)
      .text(
        `${item.productNameSnapshot}  (${quantityOrWeight.toFixed(2)} ${item.productUnitSnapshot})  ${money(lineTotal)}`
      );
  }

  doc.moveDown();
  doc.fontSize(12).text(`Estimated Total: ${money(order.estimatedTotalCents)}`);
  if (order.finalTotalCents !== null) {
    doc.text(`Final Total: ${money(order.finalTotalCents)}`);
  }

  doc.moveDown(2);
  doc.fontSize(10).text("Thank you for shopping at Oasis Markets.", {
    align: "center"
  });

  doc.end();
  return done;
};
