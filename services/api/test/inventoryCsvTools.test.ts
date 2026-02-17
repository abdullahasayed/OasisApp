import { describe, expect, it, vi } from "vitest";
import {
  executeInventoryImport,
  parseInventoryCsvContent,
  serializeInventoryCsv,
  validateInventoryCsvRows
} from "../src/tools/inventoryCsvShared.js";

describe("inventory CSV tools", () => {
  it("serializes and parses inventory CSV rows", () => {
    const csv = serializeInventoryCsv([
      {
        id: "11111111-1111-1111-1111-111111111111",
        name: "Halal Lamb Chops",
        description: "Fresh halal-cut lamb chops",
        category: "halal_meat",
        unit: "lb",
        priceCents: 1899,
        stockQuantity: 42,
        imageKey: "products/lamb.jpg",
        imageUrl: "https://example.com/lamb.jpg",
        active: true,
        searchKeywords: ["lamb", "chops", "halal"]
      }
    ]);

    const parsed = parseInventoryCsvContent(csv);
    expect(parsed.errors).toEqual([]);
    expect(parsed.rows.length).toBe(1);

    const validation = validateInventoryCsvRows(parsed.rows);
    expect(validation.errors).toEqual([]);
    expect(validation.validRows[0]?.searchKeywords).toEqual(["lamb", "chops", "halal"]);
  });

  it("normalizes and deduplicates keyword values", () => {
    const csv = [
      "id,name,description,category,unit,price_cents,stock_quantity,image_key,image_url,active,search_keywords",
      "11111111-1111-1111-1111-111111111111,Item,Desc,grocery_other,each,100,5,products/x.jpg,https://example.com/x.jpg,true,LAMB| lamb | Lamb  Chops|"
    ].join("\n");

    const parsed = parseInventoryCsvContent(csv);
    const validation = validateInventoryCsvRows(parsed.rows);
    expect(validation.errors).toEqual([]);
    expect(validation.validRows[0]?.searchKeywords).toEqual(["lamb", "lamb chops"]);
  });

  it("rejects invalid CSV header", () => {
    const csv = [
      "id,name,bad_column",
      "11111111-1111-1111-1111-111111111111,Item,Desc"
    ].join("\n");

    const parsed = parseInventoryCsvContent(csv);
    expect(parsed.errors.length).toBeGreaterThan(0);
  });

  it("reports row-level validation errors with line numbers", () => {
    const csv = [
      "id,name,description,category,unit,price_cents,stock_quantity,image_key,image_url,active,search_keywords",
      "not-a-uuid,Item,Desc,grocery_other,each,100,5,products/x.jpg,https://example.com/x.jpg,true,test"
    ].join("\n");

    const parsed = parseInventoryCsvContent(csv);
    const validation = validateInventoryCsvRows(parsed.rows);
    expect(validation.errors[0]).toContain("line 2");
  });

  it("supports dry-run import without writes", async () => {
    const upsertSpy = vi.fn(async () => Promise.resolve());
    const result = await executeInventoryImport(
      [
        {
          lineNumber: 2,
          id: "11111111-1111-1111-1111-111111111111",
          name: "Item",
          description: "",
          category: "grocery_other",
          unit: "each",
          priceCents: 100,
          stockQuantity: 10,
          imageKey: "products/x.jpg",
          imageUrl: "https://example.com/x.jpg",
          active: true,
          searchKeywords: ["item"]
        }
      ],
      {
        dryRun: true,
        upsertRow: upsertSpy
      }
    );

    expect(result.dryRun).toBe(true);
    expect(result.processedRows).toBe(1);
    expect(result.writtenRows).toBe(0);
    expect(upsertSpy).not.toHaveBeenCalled();
  });

  it("writes each row during non-dry-run import", async () => {
    const upsertSpy = vi.fn(async () => Promise.resolve());
    const result = await executeInventoryImport(
      [
        {
          lineNumber: 2,
          id: "11111111-1111-1111-1111-111111111111",
          name: "Item One",
          description: "",
          category: "grocery_other",
          unit: "each",
          priceCents: 100,
          stockQuantity: 10,
          imageKey: "products/a.jpg",
          imageUrl: "https://example.com/a.jpg",
          active: true,
          searchKeywords: ["one"]
        },
        {
          lineNumber: 3,
          id: "22222222-2222-2222-2222-222222222222",
          name: "Item Two",
          description: "",
          category: "grocery_other",
          unit: "each",
          priceCents: 120,
          stockQuantity: 8,
          imageKey: "products/b.jpg",
          imageUrl: "https://example.com/b.jpg",
          active: false,
          searchKeywords: ["two"]
        }
      ],
      {
        dryRun: false,
        upsertRow: upsertSpy
      }
    );

    expect(result.dryRun).toBe(false);
    expect(result.processedRows).toBe(2);
    expect(result.writtenRows).toBe(2);
    expect(upsertSpy).toHaveBeenCalledTimes(2);
  });
});
