import mysql from "mysql2/promise";
import type { DbConfig } from "./config.ts";

export interface Database {
  /** Round-trips a trivial query; resolves with the latency in milliseconds. */
  ping(): Promise<number>;
  close(): Promise<void>;
}

export function connectionOptions(config: DbConfig): mysql.PoolOptions {
  return {
    host: config.host,
    port: config.port,
    user: config.user,
    password: config.password,
    database: config.database,
    // Aurora enforces TLS (require_secure_transport = ON). The "Amazon RDS"
    // profile bundles the RDS certificate authorities.
    ...(config.tls ? { ssl: "Amazon RDS" } : {}),
    // Aurora Serverless v2 may be paused (scale to zero): the first
    // connection resumes it, which can take ~15 seconds.
    connectTimeout: 30_000,
    connectionLimit: 5,
    waitForConnections: true,
    enableKeepAlive: true,
  };
}

export function createDatabase(config: DbConfig): Database {
  const pool = mysql.createPool(connectionOptions(config));

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
