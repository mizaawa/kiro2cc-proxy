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

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY assets ./assets
COPY --from=frontend-builder /app/admin-ui/dist /app/admin-ui/dist
COPY --from=frontend-builder /app/user-ui/dist /app/user-ui/dist

RUN cargo build --release --locked

FROM alpine:3.21

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=builder /app/target/release/kiro2cc-proxy /app/kiro2cc-proxy

EXPOSE 5678

CMD sh -c 'mkdir -p /app/config && \
  if [ ! -f /app/config/config.json ]; then \
    echo "{\"host\":\"${HOST:-0.0.0.0}\",\"port\":${PORT:-5678},\"adminPsw\":\"${ADMIN_PSW:-$ADMIN_API_KEY}\"}" > /app/config/config.json; \
  fi && \
  if [ ! -f /app/config/credentials.json ]; then \
    echo "[]" > /app/config/credentials.json; \
  fi && \
  ./kiro2cc-proxy --config /app/config/config.json --credentials /app/config/credentials.json'
