ARG APP_NAME

FROM node:22-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV CI=true
RUN corepack enable && corepack prepare pnpm@11.9.0 --activate

FROM base AS fetcher
WORKDIR /app
COPY pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm fetch

FROM fetcher AS builder
ARG APP_NAME
WORKDIR /app
COPY . .
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --offline --frozen-lockfile
RUN pnpm build

# Isolate the monorepo service and its production dependencies
RUN pnpm deploy --filter=${APP_NAME} --prod --legacy /out
# Overlay compiled source onto the deployment
RUN cp -r dist/apps/${APP_NAME}/src /out/dist

FROM base AS runner
ARG APP_NAME

RUN apk add --no-cache dumb-init
RUN mkdir /app && chown node:node /app
WORKDIR /app
ENV NODE_ENV=production

COPY --chown=node:node --from=builder /out ./

USER node
EXPOSE 8080 8081

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD node --enable-source-maps dist/main.js
