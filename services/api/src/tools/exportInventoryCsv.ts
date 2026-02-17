import { promises as fs } from "node:fs";
import path from "node:path";
import { pool, query } from "../db/pool.js";
import { serializeInventoryCsv, type InventoryCsvExportRow } from "./inventoryCsvShared.js";

const resolveOutputPath = (args: string[]): string => {
  let outputPath = "inventory.csv";

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--out" || arg === "-o") {
      const candidate = args[index + 1];
      if (!candidate) {
        throw new Error("Missing value for --out");
      }
      outputPath = candidate;
      index += 1;
      continue;
    }

    if (arg.startsWith("--out=")) {
      outputPath = arg.slice("--out=".length);
    }
  }

  return path.resolve(process.cwd(), outputPath);
};

const run = async (): Promise<void> => {
  const outputPath = resolveOutputPath(process.argv.slice(2));
  const result = await query<Record<string, unknown>>(
    `SELECT id,
            name,
            description,
            category,
            unit,
            price_cents,
            stock_quantity,
            image_key,
            image_url,
            active,
            search_keywords
     FROM products
     ORDER BY name ASC`
  );

  const rows: InventoryCsvExportRow[] = result.rows.map((row) => ({
    id: String(row.id),
    name: String(row.name),
    description: String(row.description ?? ""),
    category: String(row.category),
    unit: String(row.unit),
    priceCents: Number(row.price_cents),
    stockQuantity: Number(row.stock_quantity),
    imageKey: String(row.image_key),
    imageUrl: String(row.image_url),
    active: Boolean(row.active),
    searchKeywords: Array.isArray(row.search_keywords)
      ? row.search_keywords.map((keyword) => String(keyword))
      : []
  }));

  const csv = serializeInventoryCsv(rows);
  await fs.writeFile(outputPath, csv, "utf8");
  // eslint-disable-next-line no-console
  console.log(`Exported ${rows.length} products to ${outputPath}`);
};

run()
  .catch((error: unknown) => {
    // eslint-disable-next-line no-console
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
