// Stack: Node.js 22.x | Express 5.x | File: server.js
// The smallest app that can fail in every way the article covers.
// It has one page, one health check, and it listens on the port the platform hands it.
const express = require("express");
const { version } = require("./package.json");

const PORT = process.env.PORT || 8080;

const app = express();

app.get("/", (req, res) => {
  res.type("text/plain").send(`container-deploy-lab v${version} · listening on ${PORT} · node ${process.version}\n`);
});

app.get("/healthz", (req, res) => {
  res.status(500).json({ ok: false, version, reason: "simulated dependency failure" }); // the page still works
});

app.listen(PORT, () => {
  console.log(`container-deploy-lab v${version} listening on ${PORT}`); // shows up in Runtime Logs
});
