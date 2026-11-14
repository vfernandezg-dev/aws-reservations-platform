import rdsCertificates from "aws-ssl-profiles";
import pg from "pg";
import type { DbConfig } from "./config.ts";

export interface Database {
  /** Round-trips a trivial query; resolves with the latency in milliseconds. */
  ping(): Promise<number>;
  close(): Promise<void>;
}

export function connectionOptions(config: DbConfig): pg.PoolConfig {
  return {
    host: config.host,
    port: config.port,
    user: config.user,
    password: config.password,
    database: config.database,
    // RDS enforces TLS (rds.force_ssl = 1). The server certificate is
    // verified against the Amazon RDS certificate authorities.
    ssl: config.tls ? { ca: rdsCertificates.ca, rejectUnauthorized: true } : false,
    // Generous timeout: a Multi-AZ failover or a cold start after
    // maintenance can take a few seconds to accept connections.
    connectionTimeoutMillis: 30_000,
    max: 5,
    idleTimeoutMillis: 60_000,
    keepAlive: true,
    application_name: "reservations-api",
  };
}

export function createDatabase(config: DbConfig): Database {
  const pool = new pg.Pool(connectionOptions(config));

  return {
    async ping() {
      const started = performance.now();
      await pool.query("SELECT 1");
      return Math.round(performance.now() - started);
    },
    async close() {
      await pool.end();
    },
  };
}
