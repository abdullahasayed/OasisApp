import bcrypt from "bcryptjs";
import { getConfig } from "../config.js";
import { query, pool } from "./pool.js";

const run = async (): Promise<void> => {
  const config = getConfig();

  const existing = await query<{ id: string }>(
    `SELECT id FROM admin_users WHERE email = $1`,
    [config.SUPERADMIN_EMAIL.toLowerCase()]
  );

  if (existing.rowCount && existing.rowCount > 0) {
    // eslint-disable-next-line no-console
    console.log("Superadmin already exists.");
    await pool.end();
    return;
  }

  const hash = await bcrypt.hash(config.SUPERADMIN_PASSWORD, 12);
  await query(
    `INSERT INTO admin_users (email, password_hash, role)
     VALUES ($1, $2, 'superadmin')`,
    [config.SUPERADMIN_EMAIL.toLowerCase(), hash]
  );

  // eslint-disable-next-line no-console
  console.log("Seeded superadmin account.");
  await pool.end();
};

run().catch(async (error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error);
  await pool.end();
  process.exit(1);
});
