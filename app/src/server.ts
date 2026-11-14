import { buildApp } from "./app.ts";
import { loadConfig } from "./config.ts";
import { createDatabase } from "./db.ts";
import { fetchTaskMetadata } from "./metadata.ts";

const config = loadConfig();
const db = config.db ? createDatabase(config.db) : undefined;

const app = buildApp({
  version: config.version,
  logLevel: config.logLevel,
  db,
  metadata: () => fetchTaskMetadata(),
});

// ECS sends SIGTERM on scale-in and deployments: stop accepting connections,
// finish in-flight requests, then close the database pool.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.once(signal, () => {
    app.log.info({ signal }, "shutting down");
    void app
      .close()
      .then(() => db?.close())
      .then(() => process.exit(0))
      .catch((error: unknown) => {
        app.log.error({ err: error }, "error during shutdown");
        process.exit(1);
      });
  });
}

await app.listen({ host: "0.0.0.0", port: config.port });
