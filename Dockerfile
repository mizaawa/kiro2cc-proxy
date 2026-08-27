FROM node:22-alpine AS frontend-builder

RUN npm install -g pnpm@11.19.0

WORKDIR /app/admin-ui
COPY admin-ui/package.json admin-ui/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY admin-ui ./
RUN pnpm build

WORKDIR /app/user-ui
COPY user-ui/package.json user-ui/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY user-ui ./
RUN pnpm build

FROM rust:1-alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static

ARG CARGO_BUILD_JOBS=1
ENV CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS}

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY assets ./assets
COPY --from=frontend-builder /app/admin-ui/dist /app/admin-ui/dist
COPY --from=frontend-builder /app/user-ui/dist /app/user-ui/dist

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/app/target \
    cargo build --profile docker --locked --jobs ${CARGO_BUILD_JOBS} && \
    cp target/docker/kiro2cc-proxy /tmp/kiro2cc-proxy

FROM alpine:3.21

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=builder /tmp/kiro2cc-proxy /app/kiro2cc-proxy

EXPOSE 5678

CMD sh -c 'mkdir -p /app/config && \
  if [ ! -f /app/config/config.json ]; then \
    echo "{\"host\":\"${HOST:-0.0.0.0}\",\"port\":${PORT:-5678},\"adminPsw\":\"${ADMIN_PSW:-$ADMIN_API_KEY}\"}" > /app/config/config.json; \
  fi && \
  if [ ! -f /app/config/credentials.json ]; then \
    echo "[]" > /app/config/credentials.json; \
  fi && \
  ./kiro2cc-proxy --config /app/config/config.json --credentials /app/config/credentials.json'
