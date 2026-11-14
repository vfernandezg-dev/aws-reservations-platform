import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import pg from "pg";
import { loadConfig } from "./config.ts";
import { connectionOptions } from "./db.ts";

/**
 * Applies SQL files from ./migrations in lexical order, exactly once each.
 * Every file runs inside its own transaction together with its bookkeeping
 * row in `schema_migrations`: PostgreSQL has transactional DDL, so a failing
 * migration leaves no partial schema behind. Runs as a one-off ECS task
 * (scripts/db-migrate.sh).
 */
const MIGRATIONS_DIR = path.resolve(import.meta.dirname, "..", "migrations");

const config = loadConfig();
if (!config.db) {
  console.error("Database configuration missing (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME).");
  process.exit(1);
}

const client = new pg.Client(connectionOptions(config.db));
await client.connect();

try {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name       TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);

  const { rows } = await client.query<{ name: string }>("SELECT name FROM schema_migrations");
  const applied = new Set(rows.map((row) => row.name));

  const files = (await readdir(MIGRATIONS_DIR)).filter((file) => file.endsWith(".sql")).sort();
  let count = 0;

  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = await readFile(path.join(MIGRATIONS_DIR, file), "utf8");
    console.log(`applying ${file}`);
    try {
      await client.query("BEGIN");
      // Without parameters, node-postgres uses the simple query protocol,
      // which accepts several statements (including $$-quoted functions).
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
    count += 1;
  }

  console.log(count === 0 ? "database is up to date" : `applied ${String(count)} migration(s)`);
} finally {
  await client.end();
}
