FROM node:24-bookworm-slim AS build

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
WORKDIR /workspace

RUN corepack enable && corepack prepare pnpm@10.13.1 --activate
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json eslint.config.mjs ./
COPY packages/api-contract/package.json packages/api-contract/package.json
COPY packages/domain-rules/package.json packages/domain-rules/package.json
COPY server/package.json server/package.json
RUN pnpm install --frozen-lockfile

COPY packages packages
COPY server server
RUN pnpm --filter @superhut/api-contract build \
 && pnpm --filter @superhut/domain-rules build \
 && pnpm --filter @superhut/server build \
 && pnpm --filter @superhut/server deploy --prod --legacy /output

FROM node:24-bookworm-slim AS runtime

ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app

COPY --from=build --chown=node:node /output ./
COPY --from=build --chown=node:node /workspace/server/drizzle ./drizzle

USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health/live').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "dist/main.js"]
