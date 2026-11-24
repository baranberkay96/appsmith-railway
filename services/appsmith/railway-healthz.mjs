// Railway healthcheck for Appsmith on PORT (IPv4 and IPv6). 200 only when the administrator
// has been created (railway-admin.sh writes the marker) and Appsmith's own health endpoint,
// reached through its Caddy, answers 200. Railway routes the public domain to a new deployment
// only after this passes, so nobody can reach the first-admin setup page.
import fs from "node:fs";
import http from "node:http";

const port = Number(process.env.PORT) || 8081;
const appPort = Number(process.env.APPSMITH_HTTP_PORT) || 80;
const marker = "/appsmith-stacks/.railway/admin-ready";

function appHealthy() {
  return new Promise((resolve) => {
    const req = http.get({ host: "127.0.0.1", port: appPort, path: "/api/v1/health", timeout: 5000 }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.on("timeout", () => req.destroy());
    req.on("error", () => resolve(false));
  });
}

http
  .createServer(async (_req, res) => {
    let status = 503;
    let body = "starting";
    if (!fs.existsSync(marker)) {
      body = "administrator not created yet";
    } else if (await appHealthy()) {
      status = 200;
      body = "ok";
    } else {
      body = "appsmith not healthy";
    }
    res.writeHead(status, { "Content-Type": "text/plain" });
    res.end(body + "\n");
  })
  .listen(port, "::");
