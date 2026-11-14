// Container health check for the distroless image (no shell or curl).
// Exit code 0 = healthy, 1 = unhealthy.
const port = process.env.PORT ?? "8080";

try {
  const response = await fetch(`http://127.0.0.1:${port}/health`, {
    signal: AbortSignal.timeout(3_000),
  });
  process.exit(response.ok ? 0 : 1);
} catch {
  process.exit(1);
}
