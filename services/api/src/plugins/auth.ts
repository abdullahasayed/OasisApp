import fp from "fastify-plugin";
import fastifyJwt from "@fastify/jwt";
import type { FastifyPluginAsync } from "fastify";
import { getConfig } from "../config.js";

const authPlugin: FastifyPluginAsync = async (app) => {
  const config = getConfig();

  await app.register(fastifyJwt, {
    secret: config.JWT_SECRET
  });

  app.decorate("authenticateAdmin", async (request, reply) => {
    try {
      await request.jwtVerify();
      const payload = request.user as { adminId: string; role: "admin" | "superadmin" };
      request.admin = {
        adminId: payload.adminId,
        role: payload.role
      };
    } catch (_error) {
      reply.code(401).send({ message: "Unauthorized" });
    }
  });

  app.decorate("authorizeSuperadmin", async (request, reply) => {
    if (!request.admin || request.admin.role !== "superadmin") {
      reply.code(403).send({ message: "Forbidden" });
    }
  });
};

export default fp(authPlugin, {
  name: "auth-plugin"
});
