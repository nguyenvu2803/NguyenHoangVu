FROM node:24-bookworm-slim
ENV NODE_ENV=production ONNXRUNTIME_NODE_INSTALL=skip PORT=8080
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY migrations ./migrations
COPY tool ./tool
RUN npm run models:fetch
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]
