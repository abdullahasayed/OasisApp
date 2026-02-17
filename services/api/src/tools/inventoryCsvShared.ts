import { productCategorySchema, productUnitSchema } from "@oasis/contracts";
import { z } from "zod";

export const INVENTORY_CSV_HEADERS = [
  "id",
  "name",
  "description",
  "category",
  "unit",
  "price_cents",
  "stock_quantity",
  "image_key",
  "image_url",
  "active",
  "search_keywords"
] as const;

export interface InventoryCsvExportRow {
  id: string;
  name: string;
  description: string;
  category: string;
  unit: string;
  priceCents: number;
  stockQuantity: number;
  imageKey: string;
  imageUrl: string;
  active: boolean;
  searchKeywords: string[];
}

export interface ParsedCsvRow {
  lineNumber: number;
  values: string[];
}

export interface ValidatedInventoryCsvRow {
  lineNumber: number;
  id: string;
  name: string;
  description: string;
  category: z.infer<typeof productCategorySchema>;
  unit: z.infer<typeof productUnitSchema>;
  priceCents: number;
  stockQuantity: number;
  imageKey: string;
  imageUrl: string;
  active: boolean;
  searchKeywords: string[];
}

interface ParseCsvRowsResult {
  rows: ParsedCsvRow[];
  errors: string[];
}

const uuidSchema = z.string().uuid();

const isLikelyTrue = (value: string): boolean => {
  return ["true", "1", "yes", "y"].includes(value.toLowerCase());
};

const isLikelyFalse = (value: string): boolean => {
  return ["false", "0", "no", "n"].includes(value.toLowerCase());
};

const collapseWhitespace = (value: string): string => {
  return value.replace(/\s+/g, " ").trim();
};

const parseCsvRows = (content: string): ParseCsvRowsResult => {
  const rows: ParsedCsvRow[] = [];
  const errors: string[] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;
  let lineNumber = 1;
  let rowStartLine = 1;

  for (let index = 0; index < content.length; index += 1) {
    const char = content[index];

    if (char === '"') {
      if (inQuotes && content[index + 1] === '"') {
        field += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char === ",") {
      row.push(field);
      field = "";
      continue;
    }

    if (!inQuotes && (char === "\n" || char === "\r")) {
      if (char === "\r" && content[index + 1] === "\n") {
        index += 1;
      }
      row.push(field);
      rows.push({ lineNumber: rowStartLine, values: row });
      row = [];
      field = "";
      lineNumber += 1;
      rowStartLine = lineNumber;
      continue;
    }

    if (char === "\n") {
      lineNumber += 1;
    }

    field += char;
  }

  if (inQuotes) {
    errors.push(`CSV parsing error: unclosed quoted field near line ${rowStartLine}`);
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push({ lineNumber: rowStartLine, values: row });
  }

  return { rows, errors };
};

const toCsvField = (value: string): string => {
  if (!/[",\r\n]/.test(value)) {
    return value;
  }

  return `"${value.replace(/"/g, "\"\"")}"`;
};

const parseNonNegativeInteger = (
  rawValue: string,
  fieldName: string,
  lineNumber: number
): number => {
  const normalized = rawValue.trim();
  if (!/^\d+$/.test(normalized)) {
    throw new Error(`line ${lineNumber}: ${fieldName} must be a non-negative integer`);
  }
  return Number(normalized);
};

const parseNonNegativeNumber = (
  rawValue: string,
  fieldName: string,
  lineNumber: number
): number => {
  const normalized = rawValue.trim();
  const parsed = Number(normalized);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`line ${lineNumber}: ${fieldName} must be a non-negative number`);
  }
  return parsed;
};

const parseBoolean = (rawValue: string, lineNumber: number): boolean => {
  const normalized = rawValue.trim();
  if (isLikelyTrue(normalized)) {
    return true;
  }
  if (isLikelyFalse(normalized)) {
    return false;
  }
  throw new Error(`line ${lineNumber}: active must be true/false`);
};

const parseKeywords = (rawValue: string): string[] => {
  const deduped = new Set<string>();
  const normalized = rawValue
    .split("|")
    .map((value) => collapseWhitespace(value).toLowerCase())
    .filter((value) => value.length > 0);

  for (const keyword of normalized) {
    deduped.add(keyword);
  }

  return Array.from(deduped);
};

export const serializeInventoryCsv = (rows: InventoryCsvExportRow[]): string => {
  const header = INVENTORY_CSV_HEADERS.join(",");
  const lines = rows.map((row) => {
    const fields = [
      row.id,
      row.name,
      row.description,
      row.category,
      row.unit,
      String(row.priceCents),
      String(row.stockQuantity),
      row.imageKey,
      row.imageUrl,
      row.active ? "true" : "false",
      row.searchKeywords.join("|")
    ];
    return fields.map(toCsvField).join(",");
  });

  return `${header}\n${lines.join("\n")}\n`;
};

export const parseInventoryCsvContent = (
  content: string
): { rows: ParsedCsvRow[]; errors: string[] } => {
  const parsed = parseCsvRows(content);
  if (parsed.errors.length > 0) {
    return { rows: [], errors: parsed.errors };
  }

  if (parsed.rows.length === 0) {
    return {
      rows: [],
      errors: ["CSV parsing error: file is empty"]
    };
  }

  const [headerRow, ...dataRows] = parsed.rows;
  const header = headerRow.values.map((value) => value.trim());
  const expectedHeader = Array.from(INVENTORY_CSV_HEADERS);

  if (header.length !== expectedHeader.length) {
    return {
      rows: [],
      errors: [
        `line ${headerRow.lineNumber}: expected ${expectedHeader.length} columns, found ${header.length}`
      ]
    };
  }

  const mismatchedIndex = expectedHeader.findIndex(
    (column, index) => header[index] !== column
  );
  if (mismatchedIndex !== -1) {
    return {
      rows: [],
      errors: [
        `line ${headerRow.lineNumber}: invalid header at column ${
          mismatchedIndex + 1
        } (expected "${expectedHeader[mismatchedIndex]}", received "${header[mismatchedIndex]}")`
      ]
    };
  }

  return {
    rows: dataRows,
    errors: []
  };
};

export const validateInventoryCsvRows = (
  rows: ParsedCsvRow[]
): { validRows: ValidatedInventoryCsvRow[]; errors: string[] } => {
  const validRows: ValidatedInventoryCsvRow[] = [];
  const errors: string[] = [];

  for (const row of rows) {
    const nonEmptyValues = row.values.filter((value) => value.trim().length > 0);
    if (nonEmptyValues.length === 0) {
      continue;
    }

    if (row.values.length !== INVENTORY_CSV_HEADERS.length) {
      errors.push(
        `line ${row.lineNumber}: expected ${INVENTORY_CSV_HEADERS.length} columns, found ${row.values.length}`
      );
      continue;
    }

    const [
      idRaw,
      nameRaw,
      descriptionRaw,
      categoryRaw,
      unitRaw,
      priceCentsRaw,
      stockQuantityRaw,
      imageKeyRaw,
      imageUrlRaw,
      activeRaw,
      keywordsRaw
    ] = row.values;

    try {
      const idValue = idRaw.trim();
      const idParsed = uuidSchema.safeParse(idValue);
      if (!idParsed.success) {
        throw new Error(`line ${row.lineNumber}: id must be a UUID`);
      }

      const name = collapseWhitespace(nameRaw);
      if (name.length < 2) {
        throw new Error(`line ${row.lineNumber}: name must be at least 2 characters`);
      }

      const description = descriptionRaw.trim();
      const categoryParsed = productCategorySchema.safeParse(categoryRaw.trim());
      if (!categoryParsed.success) {
        throw new Error(`line ${row.lineNumber}: invalid category "${categoryRaw}"`);
      }

      const unitParsed = productUnitSchema.safeParse(unitRaw.trim());
      if (!unitParsed.success) {
        throw new Error(`line ${row.lineNumber}: invalid unit "${unitRaw}"`);
      }

      const priceCents = parseNonNegativeInteger(
        priceCentsRaw,
        "price_cents",
        row.lineNumber
      );
      const stockQuantity = parseNonNegativeNumber(
        stockQuantityRaw,
        "stock_quantity",
        row.lineNumber
      );
      const imageKey = imageKeyRaw.trim();
      if (!imageKey) {
        throw new Error(`line ${row.lineNumber}: image_key is required`);
      }

      const imageUrl = imageUrlRaw.trim();
      try {
        // eslint-disable-next-line no-new
        new URL(imageUrl);
      } catch (_error) {
        throw new Error(`line ${row.lineNumber}: image_url must be a valid URL`);
      }

      const active = parseBoolean(activeRaw, row.lineNumber);
      const searchKeywords = parseKeywords(keywordsRaw);

      validRows.push({
        lineNumber: row.lineNumber,
        id: idValue,
        name,
        description,
        category: categoryParsed.data,
        unit: unitParsed.data,
        priceCents,
        stockQuantity,
        imageKey,
        imageUrl,
        active,
        searchKeywords
      });
    } catch (error) {
      errors.push(error instanceof Error ? error.message : `line ${row.lineNumber}: invalid row`);
    }
  }

  return { validRows, errors };
};

export const executeInventoryImport = async (
  rows: ValidatedInventoryCsvRow[],
  options: {
    dryRun: boolean;
    upsertRow: (row: ValidatedInventoryCsvRow) => Promise<void>;
  }
): Promise<{ dryRun: boolean; processedRows: number; writtenRows: number }> => {
  if (options.dryRun) {
    return {
      dryRun: true,
      processedRows: rows.length,
      writtenRows: 0
    };
  }

  for (const row of rows) {
    await options.upsertRow(row);
  }

  return {
    dryRun: false,
    processedRows: rows.length,
    writtenRows: rows.length
  };
};
