FROM oven/bun:alpine
WORKDIR /app
COPY package.json ./
RUN bun install
COPY . ./
ENV PORT=3000
ENV DB_PATH=/data/water.db
VOLUME ["/data"]
EXPOSE 3000
CMD ["bun", "run", "src/index.ts"]
