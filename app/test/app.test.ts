import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app.ts";
import type { Database } from "../src/db.ts";

const fakeDb = (ping: () => Promise<number>): Database => ({
  ping,
  close: () => Promise.resolve(),
});

let app: FastifyInstance;

afterEach(async () => {
  await app.close();
});

describe("health endpoints", () => {
  it("GET /health is ok without a database (ALB health check)", async () => {
    app = buildApp({ version: "test", logLevel: "silent" });
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok" });
  });

  it("GET /api/health reports the version", async () => {
    app = buildApp({ version: "abc1234", logLevel: "silent" });
    const response = await app.inject({ method: "GET", url: "/api/health" });
    expect(response.json()).toEqual({ status: "ok", version: "abc1234" });
  });
});

describe("GET /api/public/hello", () => {
  it("includes ECS task metadata when available", async () => {
    app = buildApp({
      version: "abc1234",
      logLevel: "silent",
      metadata: () =>
        Promise.resolve({
          availabilityZone: "us-east-1a",
          taskArn: "arn:aws:ecs:us-east-1:123456789012:task/cluster/0123abcd",
        }),
    });
    const response = await app.inject({ method: "GET", url: "/api/public/hello" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      version: "abc1234",
      availabilityZone: "us-east-1a",
      task: "0123abcd",
    });
  });
});

describe("GET /api/public/db-health", () => {
  it("returns latency when the database answers", async () => {
    app = buildApp({ version: "t", logLevel: "silent", db: fakeDb(() => Promise.resolve(12)) });
    const response = await app.inject({ method: "GET", url: "/api/public/db-health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok", database: "postgresql", latencyMs: 12 });
  });

  it("returns 503 when the database is unreachable", async () => {
    app = buildApp({
      version: "t",
      logLevel: "silent",
      db: fakeDb(() => Promise.reject(new Error("ETIMEDOUT"))),
    });
    const response = await app.inject({ method: "GET", url: "/api/public/db-health" });
    expect(response.statusCode).toBe(503);
  });

  it("returns 503 when no database is configured", async () => {
    app = buildApp({ version: "t", logLevel: "silent" });
    const response = await app.inject({ method: "GET", url: "/api/public/db-health" });
    expect(response.statusCode).toBe(503);
  });
});

describe("GET /api/me", () => {
  it("rejects requests without the identity header set by API Gateway", async () => {
    app = buildApp({ version: "t", logLevel: "silent" });
    const response = await app.inject({ method: "GET", url: "/api/me" });
    expect(response.statusCode).toBe(401);
  });

  it("returns the caller identity from the verified JWT claims", async () => {
    app = buildApp({ version: "t", logLevel: "silent" });
    const response = await app.inject({
      method: "GET",
      url: "/api/me",
      headers: { "x-user-sub": "1234-abcd", "x-user-email": "user@example.com" },
    });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ sub: "1234-abcd", email: "user@example.com" });
  });
});
