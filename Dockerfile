# ---------- Etapa 1: dependencias ----------
FROM node:22-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

# ---------- Etapa 2: test ----------
FROM node:22-alpine AS test
WORKDIR /app
COPY app/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY app/ .
RUN npm test && touch /tests-ok

# ---------- Etapa 3: runtime mínimo ----------
FROM node:22-alpine AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
# Depender de la etapa test garantiza que la imagen final solo se construye si los tests pasan
COPY --from=test /tests-ok /tmp/tests-ok
COPY --from=deps --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app app/package.json ./
COPY --chown=app:app app/src ./src
USER 10001:10001
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "src/server.js"]
