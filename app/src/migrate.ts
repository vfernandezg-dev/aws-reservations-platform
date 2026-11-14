import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import mysql from "mysql2/promise";
import { loadConfig } from "./config.ts";
import { connectionOptions } from "./db.ts";

/**
 * Applies SQL files from ./migrations in lexical order, exactly once each.
 * Applied files are recorded in `schema_migrations`. Each file is sent as a
 * single multi-statement query, so trigger bodies (BEGIN ... END) need no
 * DELIMITER tricks. Runs as a one-off ECS task (scripts/db-migrate.sh).
 */
const MIGRATIONS_DIR = path.resolve(import.meta.dirname, "..", "migrations");

const config = loadConfig();
if (!config.db) {
  console.error("Database configuration missing (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME).");
  process.exit(1);
}

const connection = await mysql.createConnection({
  ...connectionOptions(config.db),
  multipleStatements: true,
});

try {
  await connection.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name       VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

  const [rows] = await connection.query<mysql.RowDataPacket[]>("SELECT name FROM schema_migrations");
  const applied = new Set(rows.map((row) => String(row.name)));

  const files = (await readdir(MIGRATIONS_DIR)).filter((file) => file.endsWith(".sql")).sort();
  let count = 0;

  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = await readFile(path.join(MIGRATIONS_DIR, file), "utf8");
    console.log(`applying ${file}`);
    await connection.query(sql);
    await connection.query("INSERT INTO schema_migrations (name) VALUES (?)", [file]);
    count += 1;
  }

  console.log(count === 0 ? "database is up to date" : `applied ${String(count)} migration(s)`);
} finally {
  await connection.end();
}
