import { buildApp } from "./app.js";
import { getConfig } from "./config.js";
import { pool } from "./db/pool.js";

const run = async (): Promise<void> => {
  const config = getConfig();
  const app = await buildApp();

  const close = async (): Promise<void> => {
    await app.close();
    await pool.end();
  };

  process.on("SIGINT", () => {
    void close().then(() => process.exit(0));
  });
  process.on("SIGTERM", () => {
    void close().then(() => process.exit(0));
  });

  await app.listen({ port: config.PORT, host: "0.0.0.0" });
};

run().catch(async (error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error);
  await pool.end();
  process.exit(1);
});
