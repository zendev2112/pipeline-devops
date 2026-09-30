# ---------- Etapa 1: dependencias ----------
FROM node:26-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

# ---------- Etapa 2: test ----------
FROM node:26-alpine AS test
WORKDIR /app
COPY app/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY app/ .
RUN npm test

# ---------- Etapa 3: runtime mínimo ----------
FROM node:26-alpine AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=deps --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app app/package.json ./
COPY --chown=app:app app/src ./src
USER app
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "src/server.js"]
