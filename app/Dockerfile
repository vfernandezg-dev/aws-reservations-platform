# syntax=docker/dockerfile:1.12
# Multi-stage build for linux/arm64 (Graviton) and linux/amd64.
# Base images are pinned by digest; Dependabot keeps them up to date.

# ---------------------------------------------------------------------------
# Build: compile TypeScript and install production dependencies only.
# Runs on the native build platform: the output is plain JavaScript with no
# native addons, so cross-building for arm64 needs no CPU emulation.
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM node:26-trixie-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# ---------------------------------------------------------------------------
# Runtime: distroless (no shell, no package manager), non-root user
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/nodejs26-debian13:nonroot@sha256:1d736cf8b5716c07a245301f92717143215d248fd55771ee1936ef4b3302e531
WORKDIR /app

ENV NODE_ENV=production \
    PORT=8080

COPY --from=build --chown=65532:65532 /app/node_modules ./node_modules
COPY --from=build --chown=65532:65532 /app/dist ./dist
COPY --chown=65532:65532 package.json ./
COPY --chown=65532:65532 migrations ./migrations

USER 65532:65532
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/nodejs/bin/node", "dist/healthcheck.js"]

# The distroless entrypoint is the node binary.
CMD ["dist/server.js"]
