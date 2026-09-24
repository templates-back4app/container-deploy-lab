# Stack: Docker | Node.js 22 (Debian bookworm, with gcc, g++, make and python3 preinstalled) | File: Dockerfile
FROM node:22
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.js"]
