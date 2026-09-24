# Stack: Docker | Node.js 22 (alpine) | File: Dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
COPY config/settings.json ./
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.js"]
