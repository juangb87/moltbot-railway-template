# ---- Build OpenClaw ----
FROM node:22-bookworm AS openclaw-build
WORKDIR /openclaw

ARG OPENCLAW_VERSION=v2026.2.13

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git python3 make g++ pkg-config \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable

# Clone OpenClaw and pin version/tag
RUN git clone https://github.com/openclaw/openclaw.git /openclaw \
  && git checkout "${OPENCLAW_VERSION}"

RUN pnpm install
RUN pnpm build
RUN pnpm ui:build

# ---- Runtime image ----
FROM node:22-bookworm
ENV NODE_ENV=production
ENV HOME=/data

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl procps file git python3 sudo \
  && rm -rf /var/lib/apt/lists/*

# Copy built openclaw
COPY --from=openclaw-build /openclaw /openclaw

# Provide an openclaw executable
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/dist/entry.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

WORKDIR /app
COPY package.json ./
RUN corepack enable && pnpm install --prod

COPY src ./src

ENV PORT=8080
EXPOSE 8080
CMD ["node", "src/server.js"]
