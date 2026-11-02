FROM node:22-alpine
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN corepack enable && pnpm install --prod --frozen-lockfile
COPY . .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "server/index.js"]
