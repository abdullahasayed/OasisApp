import {
  Pool,
  type PoolClient,
  type QueryResult,
  type QueryResultRow
} from "pg";
import { getConfig } from "../config.js";

const config = getConfig();

export const pool = new Pool({
  connectionString: config.DATABASE_URL
});

export const query = async <T extends QueryResultRow>(
  text: string,
  values?: unknown[]
): Promise<QueryResult<T>> => {
  return pool.query<T>(text, values);
};

export const withTransaction = async <T>(
  run: (client: PoolClient) => Promise<T>
): Promise<T> => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await run(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
