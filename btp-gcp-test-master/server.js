const http = require('node:http');

function createServer() {
  return http.createServer((request, response) => {
    const routes = { '/': 'Hello World', '/healthz': 'OK', '/version': process.env.APP_VERSION || 'unknown' };
    const body = routes[request.url];
    response.writeHead(body === undefined ? 404 : 200, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end(body);
  });
}

if (require.main === module) {
  const server = createServer().listen(process.env.PORT || 3000);
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
}

module.exports = { createServer };
