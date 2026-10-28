const assert = require("node:assert/strict");
const { once } = require("node:events");
const fs = require("node:fs/promises");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const express = require("express");
const api = require("./api");
const logger = require("./misc/logger");
const pool = require("./db/pool").db.pool;

const setup = async (context, query) => {
  const output = [];
  for (const level of ["log", "warn", "error"]) {
    context.mock.method(console, level, (line) => output.push(String(line)));
  }
  context.mock.method(pool, "query", query);
  const app = express();
  app.use(logger.logreq);
  app.use(express.json());
  app.post("/api/secure/categories/get", api.getCategories);
  app.use((error, req, res, next) => res.status(500).json({ error: "Query failed" }));
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  context.after(() => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  return {
    output,
    entries: () => output.map((line) => JSON.parse(line.slice(line.indexOf("{")))),
    request: () => new Promise((resolve, reject) => {
      const req = http.request({
        hostname: "127.0.0.1", port: server.address().port,
        path: "/api/secure/categories/get?token=private-query-token", method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "private-api-key" },
      }, async (res) => {
        const chunks = [];
        for await (const chunk of res) chunks.push(chunk);
        resolve({ status: res.statusCode, requestId: res.headers["x-request-id"], body: JSON.parse(Buffer.concat(chunks)) });
      });
      req.on("error", reject);
      req.end(JSON.stringify({ PjNr: 123, user: { name: "TEST", pass: "private-password" }, comment: "private-inspection-text" }));
    }),
  };
};

const assertPrivateFieldsAbsent = (output) => {
  const text = output.join("\n");
  for (const secret of ["private-api-key", "private-query-token", "private-password", "private-inspection-text"]) {
    assert.equal(text.includes(secret), false, secret);
  }
};

test("database and handler errors retain the HTTP request id without logging credentials", async (context) => {
  const failure = Object.assign(new Error("Relation does not exist"), { code: "42P01" });
  const app = await setup(context, (sql, parameters, callback) => setImmediate(() => callback(failure)));
  const response = await app.request();
  assert.equal(response.status, 500);
  assert.ok(response.requestId);
  const entries = app.entries();
  for (const event of ["query-failed", "handler-failed", "finished"]) {
    const entry = entries.find((item) => item.event === event);
    assert.ok(entry, event);
    assert.equal(entry.requestId, response.requestId);
  }
  assert.equal(entries.find((item) => item.event === "query-failed").errorCode, "42P01");
  assert.equal(entries.find((item) => item.event === "finished").status, 500);
  assertPrivateFieldsAbsent(app.output);
});

test("storage failures are correlated and reported as 503 instead of empty results", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-log-storage-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  const app = await setup(context, (sql, parameters, callback) => setImmediate(() => callback(null, {
    rows: [{ PjNr: 123, LinkOrdner: path.join(directory, "missing") }],
  })));
  const response = await app.request();
  assert.equal(response.status, 503);
  assert.equal(response.body.error.code, "STORAGE_UNAVAILABLE");
  const failed = app.entries().find((entry) => entry.event === "handler-failed");
  assert.equal(failed.requestId, response.requestId);
  assert.equal(failed.errorCode, "ENOENT");
  assert.equal(failed.pjNr, 123);
  assertPrivateFieldsAbsent(app.output);
});

test("slow requests and queries emit warnings with the same request id", async (context) => {
  for (const key of ["BACKEND_SLOW_REQUEST_MS", "BACKEND_SLOW_QUERY_MS"]) {
    const previous = process.env[key];
    process.env[key] = "1";
    context.after(() => {
      if (previous === undefined) delete process.env[key];
      else process.env[key] = previous;
    });
  }
  const app = await setup(context, (sql, parameters, callback) => setTimeout(() => callback(null, { rows: [] }), 25));
  const response = await app.request();
  assert.equal(response.status, 200);
  for (const event of ["slow", "slow-query"]) {
    const entry = app.entries().find((item) => item.event === event);
    assert.ok(entry, event);
    assert.equal(entry.requestId, response.requestId);
    assert.ok(Number.isFinite(entry.durationMs) && entry.durationMs >= 0);
  }
  assertPrivateFieldsAbsent(app.output);
});
