import Fastify, { type FastifyInstance } from "fastify";
import type { Database } from "./db.ts";
import type { TaskMetadata } from "./metadata.ts";

export interface AppOptions {
  version: string;
  logLevel?: string;
  db?: Database | undefined;
  metadata?: () => Promise<TaskMetadata>;
}

/**
 * Builds the HTTP application. Every external dependency is injected so the
 * routes can be tested with `app.inject()` and no network access.
 *
 * Routing contract with the infrastructure:
 * - GET /health                 ALB target health check. Never touches the DB.
 * - GET /api/health             Public liveness through CloudFront.
 * - GET /api/public/hello       Anonymous demo endpoint.
 * - GET /api/public/db-health   Anonymous DB round-trip (wakes Aurora up).
 * - GET /api/me                 Protected: API Gateway validates the Cognito
 *                               JWT and forwards the `sub` claim as x-user-sub.
 */
export function buildApp(options: AppOptions): FastifyInstance {
  const app = Fastify({
    logger: { level: options.logLevel ?? "info" },
    trustProxy: true,
    requestIdHeader: "x-amzn-trace-id",
  });

  const metadata =
    options.metadata ?? (() => Promise.resolve({ availabilityZone: undefined, taskArn: undefined }));

  app.get("/health", () => ({ status: "ok" }));

  app.get("/api/health", () => ({ status: "ok", version: options.version }));

  app.get("/api/public/hello", async () => {
    const task = await metadata();
    return {
      message: "Hello from ECS Fargate (ARM64) behind CloudFront, API Gateway and an internal ALB",
      version: options.version,
      availabilityZone: task.availabilityZone ?? "local",
      task: task.taskArn?.split("/").at(-1) ?? "local",
      timestamp: new Date().toISOString(),
    };
  });

  app.get("/api/public/db-health", async (request, reply) => {
    if (!options.db) {
      return reply.code(503).send({ status: "unavailable", reason: "database not configured" });
    }
    try {
      const latencyMs = await options.db.ping();
      return { status: "ok", database: "aurora-mysql", latencyMs };
    } catch (error) {
      request.log.error({ err: error }, "database ping failed");
      return reply.code(503).send({ status: "unavailable", reason: "database unreachable" });
    }
  });

  app.get("/api/me", (request, reply) => {
    const subject = request.headers["x-user-sub"];
    if (typeof subject !== "string" || subject === "") {
      return reply.code(401).send({ message: "Unauthorized" });
    }
    const email = request.headers["x-user-email"];
    return { sub: subject, email: typeof email === "string" ? email : null };
  });

  return app;
}
