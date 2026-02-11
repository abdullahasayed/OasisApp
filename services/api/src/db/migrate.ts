import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "./pool.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationsDir = path.join(__dirname, "migrations");

const run = async (): Promise<void> => {
  const files = (await fs.readdir(migrationsDir))
    .filter((name) => name.endsWith(".sql"))
    .sort();

  for (const file of files) {
    const fullPath = path.join(migrationsDir, file);
    const sql = await fs.readFile(fullPath, "utf8");
    // Single connection keeps extension/table creation deterministic.
    await pool.query(sql);
    // eslint-disable-next-line no-console
    console.log(`Applied migration ${file}`);
  }

  await pool.end();
};

run().catch(async (error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error);
  await pool.end();
  process.exit(1);
});
