import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  API_BASE_URL: z.string().url().default("http://localhost:4000"),
  JWT_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_EXPIRES_IN: z.string().default("15m"),
  JWT_REFRESH_EXPIRES_IN: z.string().default("30d"),
  DATABASE_URL: z.string().min(1),
  STORE_TIMEZONE: z.string().default("America/Chicago"),
  STORE_OPEN_TIME: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .default("09:00"),
  STORE_CLOSE_TIME: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .default("20:00"),
  SLOT_MINUTES: z.coerce.number().int().positive().default(30),
  SLOT_CAPACITY: z.coerce.number().int().positive().default(20),
  LEAD_TIME_MINUTES: z.coerce.number().int().nonnegative().default(60),
  TAX_RATE_BPS: z.coerce.number().int().min(0).max(10000).default(0),
  SUPERADMIN_EMAIL: z.string().email(),
  SUPERADMIN_PASSWORD: z.string().min(8),
  PAYMENT_PROVIDER: z.enum(["stripe", "mock"]).default("stripe"),
  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
  STORAGE_PROVIDER: z.enum(["s3", "local"]).default("local"),
  S3_BUCKET: z.string().default("oasis-assets"),
  S3_REGION: z.string().default("us-east-1"),
  S3_ENDPOINT: z.string().url().optional(),
  S3_ACCESS_KEY: z.string().optional(),
  S3_SECRET_KEY: z.string().optional(),
  S3_FORCE_PATH_STYLE: z
    .string()
    .optional()
    .transform((v) => v === "true"),
  RECEIPT_URL_TTL_SECONDS: z.coerce.number().int().positive().default(86400)
});

export type AppConfig = z.infer<typeof envSchema>;

let cachedConfig: AppConfig | null = null;

export const getConfig = (): AppConfig => {
  if (cachedConfig) {
    return cachedConfig;
  }

  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("\n");
    throw new Error(`Invalid environment configuration:\n${details}`);
  }

  cachedConfig = parsed.data;
  return parsed.data;
};
