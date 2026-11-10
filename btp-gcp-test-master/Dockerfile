FROM node:22-alpine AS test
WORKDIR /app
COPY package.json server.js ./
COPY test ./test
RUN npm test

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --from=test /app/package.json /app/server.js ./
USER node
EXPOSE 3000
CMD ["node", "server.js"]
