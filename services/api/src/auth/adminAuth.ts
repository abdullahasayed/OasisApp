import bcrypt from "bcryptjs";
import type { FastifyInstance } from "fastify";
import type { AdminRole } from "@oasis/contracts";
import { getConfig } from "../config.js";
import { createAdminUser, findAdminByEmail } from "../db/repositories.js";

export interface AdminTokenPayload {
  adminId: string;
  role: AdminRole;
}

export const verifyAdminPassword = async (
  email: string,
  password: string
): Promise<{ id: string; role: AdminRole } | null> => {
  const admin = await findAdminByEmail(email.toLowerCase());
  if (!admin) {
    return null;
  }

  const match = await bcrypt.compare(password, admin.passwordHash);
  if (!match) {
    return null;
  }

  return {
    id: admin.id,
    role: admin.role
  };
};

export const issueAdminTokens = async (
  app: FastifyInstance,
  payload: AdminTokenPayload
): Promise<{ accessToken: string; refreshToken: string }> => {
  const config = getConfig();

  const accessToken = await app.jwt.sign(payload, {
    expiresIn: config.JWT_EXPIRES_IN
  });

  const refreshToken = await app.jwt.sign(payload, {
    expiresIn: config.JWT_REFRESH_EXPIRES_IN,
    key: config.JWT_REFRESH_SECRET
  });

  return {
    accessToken,
    refreshToken
  };
};

export const ensureSeedSuperadmin = async (): Promise<void> => {
  const config = getConfig();
  const existing = await findAdminByEmail(config.SUPERADMIN_EMAIL.toLowerCase());
  if (existing) {
    return;
  }

  const hash = await bcrypt.hash(config.SUPERADMIN_PASSWORD, 12);
  await createAdminUser(config.SUPERADMIN_EMAIL.toLowerCase(), hash, "superadmin");
};
