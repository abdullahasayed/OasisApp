import { promises as fs } from "node:fs";
import path from "node:path";
import { pool, withTransaction } from "../db/pool.js";
import {
  executeInventoryImport,
  parseInventoryCsvContent,
  validateInventoryCsvRows,
  type ValidatedInventoryCsvRow
} from "./inventoryCsvShared.js";

interface ImportArgs {
  inputPath: string;
  dryRun: boolean;
}

const parseArgs = (args: string[]): ImportArgs => {
  let inputPath = "";
  let dryRun = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--dry-run") {
      dryRun = true;
      continue;
    }

    if (arg === "--in" || arg === "-i") {
      const candidate = args[index + 1];
      if (!candidate) {
        throw new Error("Missing value for --in");
      }
      inputPath = candidate;
      index += 1;
      continue;
    }

    if (arg.startsWith("--in=")) {
      inputPath = arg.slice("--in=".length);
      continue;
    }
  }

  if (!inputPath) {
    throw new Error("Missing required --in <path-to-csv> argument");
  }

  return {
    inputPath: path.resolve(process.cwd(), inputPath),
    dryRun
  };
};

const buildParseError = (errors: string[]): Error => {
  return new Error(`Inventory CSV validation failed:\n${errors.join("\n")}`);
};

const upsertRowSql = async (
  upsertRow: ValidatedInventoryCsvRow,
  runner: { query: (queryText: string, params?: unknown[]) => Promise<unknown> }
): Promise<void> => {
  await runner.query(
    `INSERT INTO products (
       id,
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
     ) VALUES (
       $1::uuid,
       $2,
       $3,
       $4,
       $5,
       $6,
       $7,
       $8,
       $9,
       $10,
       $11::text[]
     )
     ON CONFLICT (id)
     DO UPDATE SET
       name = EXCLUDED.name,
       description = EXCLUDED.description,
       category = EXCLUDED.category,
       unit = EXCLUDED.unit,
       price_cents = EXCLUDED.price_cents,
       stock_quantity = EXCLUDED.stock_quantity,
       image_key = EXCLUDED.image_key,
       image_url = EXCLUDED.image_url,
       active = EXCLUDED.active,
       search_keywords = EXCLUDED.search_keywords,
       updated_at = NOW()`,
    [
      upsertRow.id,
      upsertRow.name,
      upsertRow.description,
      upsertRow.category,
      upsertRow.unit,
      upsertRow.priceCents,
      upsertRow.stockQuantity,
      upsertRow.imageKey,
      upsertRow.imageUrl,
      upsertRow.active,
      upsertRow.searchKeywords
    ]
  );
};

const run = async (): Promise<void> => {
  const { inputPath, dryRun } = parseArgs(process.argv.slice(2));
  const content = await fs.readFile(inputPath, "utf8");
  const parsed = parseInventoryCsvContent(content);
  if (parsed.errors.length > 0) {
    throw buildParseError(parsed.errors);
  }

  const validation = validateInventoryCsvRows(parsed.rows);
  if (validation.errors.length > 0) {
    throw buildParseError(validation.errors);
  }

  if (validation.validRows.length === 0) {
    throw new Error("Inventory CSV contains no data rows to import");
  }

  if (dryRun) {
    const dryRunResult = await executeInventoryImport(validation.validRows, {
      dryRun: true,
      upsertRow: async () => Promise.resolve()
    });
    // eslint-disable-next-line no-console
    console.log(
      `[DRY RUN] Validated ${dryRunResult.processedRows} rows from ${inputPath}. No database writes performed.`
    );
    return;
  }

  await withTransaction(async (client) => {
    await executeInventoryImport(validation.validRows, {
      dryRun: false,
      upsertRow: async (row) => {
        await upsertRowSql(row, client);
      }
    });
  });

  // eslint-disable-next-line no-console
  console.log(`Imported ${validation.validRows.length} rows from ${inputPath}`);
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
