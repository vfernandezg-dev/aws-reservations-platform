export interface DbConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  /** TLS with the Amazon RDS CA bundle. Disable only for a local database. */
  tls: boolean;
}

export interface Config {
  port: number;
  version: string;
  logLevel: string;
  db: DbConfig | undefined;
}

function intFromEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const value = Number.parseInt(raw, 10);
  if (Number.isNaN(value)) throw new Error(`${name} must be an integer, got "${raw}"`);
  return value;
}

/**
 * Reads configuration from environment variables. Database settings are
 * optional so the service can start (and pass health checks) without them;
 * DB_USER / DB_PASSWORD are injected by ECS from Secrets Manager.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const { DB_HOST, DB_USER, DB_PASSWORD, DB_NAME } = env;

  return {
    port: intFromEnv("PORT", 8080),
    version: env.APP_VERSION ?? "dev",
    logLevel: env.LOG_LEVEL ?? "info",
    db:
      DB_HOST && DB_USER && DB_PASSWORD && DB_NAME
        ? {
            host: DB_HOST,
            port: intFromEnv("DB_PORT", 3306),
            user: DB_USER,
            password: DB_PASSWORD,
            database: DB_NAME,
            tls: env.DB_TLS !== "false",
          }
        : undefined,
  };
}
