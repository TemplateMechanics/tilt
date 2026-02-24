# Multi-stage Dockerfile for custom Backstage image with Tilt plugin
# Build context: backstage/app/

# ---- Stage 1: Install dependencies and build ----
FROM node:22-bookworm-slim AS build

ENV PYTHON=/usr/bin/python3

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /app

# Copy Yarn config and lockfile first for layer caching
COPY --chown=node:node .yarn ./.yarn
COPY --chown=node:node .yarnrc.yml package.json yarn.lock backstage.json ./

# Copy all package.json files (workspaces)
COPY --chown=node:node packages/backend/package.json ./packages/backend/package.json
COPY --chown=node:node packages/app/package.json ./packages/app/package.json
COPY --chown=node:node plugins/tilt/package.json ./plugins/tilt/package.json

# Install all dependencies (including dev for build)
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable

# Copy the full source
COPY --chown=node:node . .

# Build the backend (bundles frontend as well)
RUN yarn tsc && yarn build:backend

# ---- Stage 2: Production image ----
FROM node:22-bookworm-slim

ENV PYTHON=/usr/bin/python3

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /app

# Copy Yarn config
COPY --chown=node:node --from=build /app/.yarn ./.yarn
COPY --chown=node:node --from=build /app/.yarnrc.yml ./
COPY --chown=node:node --from=build /app/backstage.json ./

ENV NODE_ENV=production
ENV NODE_OPTIONS="--no-node-snapshot"

# Extract skeleton (package.json files + yarn.lock) for production install
COPY --chown=node:node --from=build /app/yarn.lock /app/package.json ./
COPY --chown=node:node --from=build /app/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

# Install production dependencies only
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

# Copy the backend bundle
COPY --chown=node:node --from=build /app/packages/backend/dist/bundle.tar.gz ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Copy app-config files
COPY --chown=node:node app-config*.yaml ./

CMD ["node", "packages/backend", "--config", "app-config.yaml"]
