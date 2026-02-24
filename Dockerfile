# syntax=docker/dockerfile:1

# ─── Stage 1: Install dependencies ────────────────────────────────────────────
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat python3 make g++
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

# ─── Stage 2: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable Nuxt telemetry during build
ENV NUXT_TELEMETRY_DISABLED=1

RUN npm run build

# ─── Stage 3: Production runner ───────────────────────────────────────────────
FROM node:20-alpine AS runner
RUN apk add --no-cache libc6-compat
WORKDIR /app

ENV NODE_ENV=production
ENV NUXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOST=0.0.0.0

# Non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nuxtjs

# Copy only the Nitro server output
COPY --from=builder --chown=nuxtjs:nodejs /app/.output ./

USER nuxtjs

EXPOSE 3000

CMD ["node", "server/index.mjs"]
