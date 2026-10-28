const assert = require("node:assert/strict");
const { once } = require("node:events");
const fs = require("node:fs/promises");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const { PassThrough } = require("node:stream");
const test = require("node:test");
const express = require("express");

const api = require("./api");
const queries = require("./db/queries");
const imageFilesystem = require("./images/filesystem");
const imageHashes = require("./images/hash");
const logger = require("./misc/logger");

const setup = async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-api-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  context.mock.method(logger, "logEvent", () => {});
  const app = express();
  app.use(express.json());
  app.use((req, res, next) => {
    req.user = { KZL: "TEST" };
    next();
  });
  app.post("/image/get", api.getFileFromHash);
  app.get("/get/:hash", api.getFileFromHash_get);
  app.post("/doc/get", api.getDocFromPath);
  app.post("/categories/get", api.getCategories);
  app.use((error, req, res, next) => res.status(500).json({ error: "Unexpected error" }));
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  context.after(() => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  return { directory, port: server.address().port };
};

const request = (port, route, body) => new Promise((resolve, reject) => {
  const connection = http.request({
    hostname: "127.0.0.1", port, path: route,
    method: body === undefined ? "GET" : "POST",
    headers: { "Content-Type": "application/json" },
  }, async (response) => {
    try {
      const chunks = [];
      for await (const chunk of response) chunks.push(chunk);
      resolve({ status: response.statusCode, headers: response.headers, body: Buffer.concat(chunks) });
    } catch (error) {
      reject(error);
    }
  });
  connection.on("error", reject);
  connection.end(body === undefined ? undefined : JSON.stringify(body));
});

test("POST and GET image downloads stream bytes with existing filename and MIME headers", async (context) => {
  const { directory, port } = await setup(context);
  const contents = Buffer.alloc(768 * 1024, 57);
  await fs.writeFile(path.join(directory, "photo.png"), contents);
  const hash = imageHashes.memorize(directory, "", "photo.png");
  context.mock.method(fs, "readFile", () => { throw new Error("Downloads must not buffer entire files"); });
  const responses = await Promise.all([
    request(port, "/image/get", { hash }),
    request(port, `/get/${encodeURIComponent(hash)}`),
  ]);
  for (const response of responses) {
    assert.equal(response.status, 200);
    assert.equal(response.headers["content-type"], "image/png");
    assert.equal(response.headers["x-image-filename"], "photo.png");
    assert.equal(Number(response.headers["content-length"]), contents.length);
    assert.deepEqual(response.body, contents);
  }
});

test("documents use the authenticated user's directories and stream without readFile", async (context) => {
  const { directory, port } = await setup(context);
  const documentPath = path.join(directory, "report.pdf");
  await fs.writeFile(documentPath, "PDF data");
  context.mock.method(queries, "getDocumentDirectoriesForUser", async (user) => {
    assert.deepEqual(user, { KZL: "TEST" });
    return [directory];
  });
  context.mock.method(fs, "readFile", () => { throw new Error("Downloads must stream"); });
  for (const body of [{ docPath: documentPath }, { docPath: directory, filename: "report.pdf" }]) {
    const response = await request(port, "/doc/get", { ...body, user: { KZL: "OTHER" } });
    assert.equal(response.status, 200);
    assert.equal(response.headers["content-type"], "application/octet-stream");
    assert.equal(response.body.toString(), "PDF data");
  }
});

test("documents return 403 for unauthorized paths and escaping symlinks", async (context) => {
  const { directory, port } = await setup(context);
  const documents = path.join(directory, "Dokus");
  await fs.mkdir(documents);
  await fs.writeFile(path.join(directory, "private.txt"), "secret");
  await fs.symlink(path.join(directory, "private.txt"), path.join(documents, "linked.pdf"));
  context.mock.method(queries, "getDocumentDirectoriesForUser", async () => [documents]);
  for (const docPath of [path.join(directory, "private.txt"), `${documents}/../private.txt`, path.join(documents, "linked.pdf")]) {
    const response = await request(port, "/doc/get", { docPath });
    assert.equal(response.status, 403);
    assert.equal(JSON.parse(response.body).code, "FORBIDDEN_PATH");
    assert.equal(response.body.includes("secret"), false);
  }
});

test("documents are denied when the user has no allowed directories", async (context) => {
  const { directory, port } = await setup(context);
  await fs.writeFile(path.join(directory, "report.pdf"), "secret");
  context.mock.method(queries, "getDocumentDirectoriesForUser", async () => []);
  const response = await request(port, "/doc/get", { docPath: path.join(directory, "report.pdf") });
  assert.equal(response.status, 403);
});

test("invalid inputs, missing files and failed storage have distinct HTTP responses", async (context) => {
  const { directory, port } = await setup(context);
  context.mock.method(queries, "getDocumentDirectoriesForUser", async () => [directory]);
  const missingImage = imageHashes.memorize(directory, "", "missing.jpg");
  const cases = [
    ["/image/get", {}, 400, "INVALID_HASH"],
    ["/image/get", { hash: { toString: null } }, 400, "INVALID_HASH"],
    ["/image/get", { hash: "unknown" }, 404, "FILE_NOT_FOUND"],
    ["/image/get", { hash: missingImage }, 404, "FILE_NOT_FOUND"],
    ["/doc/get", {}, 400, "INVALID_PATH"],
    ["/doc/get", { docPath: directory }, 400, "INVALID_PATH"],
    ["/doc/get", { docPath: directory, filename: "../private.txt" }, 400, "INVALID_PATH"],
    ["/doc/get", { docPath: path.join(directory, "missing.pdf") }, 404, "FILE_NOT_FOUND"],
  ];
  for (const [route, body, status, code] of cases) {
    const response = await request(port, route, body);
    assert.equal(response.status, status);
    assert.equal(JSON.parse(response.body).code, code);
    assert.match(response.headers["content-type"], /application\/json/);
  }
  context.mock.method(fs, "open", async () => {
    throw Object.assign(new Error("Permission denied"), { code: "EACCES", syscall: "open" });
  });
  const denied = await request(port, "/image/get", { hash: missingImage });
  assert.equal(denied.status, 503);
  assert.equal(JSON.parse(denied.body).code, "STORAGE_UNAVAILABLE");
  assert.equal(denied.body.includes(directory), false);
});

test("unavailable image and document directories return 503 instead of 404", async (context) => {
  const { directory, port } = await setup(context);
  const missingDirectory = path.join(directory, "unavailable");
  context.mock.method(queries, "getDocumentDirectoriesForUser", async () => [missingDirectory]);
  const hash = imageHashes.memorize(missingDirectory, "", "photo.jpg");
  for (const [route, body] of [
    ["/image/get", { hash }],
    ["/doc/get", { docPath: path.join(missingDirectory, "report.pdf") }],
  ]) {
    const response = await request(port, route, body);
    assert.equal(response.status, 503);
    assert.equal(JSON.parse(response.body).code, "STORAGE_UNAVAILABLE");
  }
});

test("list endpoints return 503 rather than an empty success on storage failure", async (context) => {
  const { port } = await setup(context);
  context.mock.method(queries, "getCheckCategoriesForPjNR", async () => ({
    hashImagesAndCreateIds: async () => {
      throw new imageFilesystem.StorageUnavailableError(Object.assign(new Error("Network unavailable"), { code: "EIO" }));
    },
  }));
  const response = await request(port, "/categories/get", { PjNr: 123 });
  assert.equal(response.status, 503);
  assert.equal(JSON.parse(response.body).error.code, "STORAGE_UNAVAILABLE");
});

test("empty files download successfully", async (context) => {
  const { directory, port } = await setup(context);
  await fs.writeFile(path.join(directory, "empty.jpg"), "");
  const hash = imageHashes.memorize(directory, "", "empty.jpg");
  const response = await request(port, "/image/get", { hash });
  assert.equal(response.status, 200);
  assert.equal(response.body.length, 0);
  assert.equal(response.headers["content-length"], "0");
});

test("disconnecting a download closes the source stream", { timeout: 5000 }, async (context) => {
  const { port } = await setup(context);
  const source = new PassThrough();
  const closed = new Promise((resolve) => source.once("close", resolve));
  context.mock.method(imageHashes, "getFileFromHash", async () => ({ stream: source, size: 1000000 }));
  source.write(Buffer.alloc(1024));
  await new Promise((resolve, reject) => {
    const connection = http.get(`http://127.0.0.1:${port}/get/abort-test`, (response) => {
      response.once("data", () => {
        response.destroy();
        resolve();
      });
    });
    connection.on("error", reject);
  });
  await closed;
  assert.equal(source.destroyed, true);
});

test("late disk errors terminate the download without appending a JSON error", { timeout: 5000 }, async (context) => {
  const { port } = await setup(context);
  const source = new PassThrough();
  context.mock.method(imageHashes, "getFileFromHash", async () => ({ stream: source, size: 1000000 }));
  source.write(Buffer.alloc(1024, 65));
  await new Promise((resolve, reject) => {
    const connection = http.get(`http://127.0.0.1:${port}/get/error-test`, (response) => {
      const chunks = [];
      response.on("data", (chunk) => {
        chunks.push(chunk);
        source.destroy(Object.assign(new Error("Disk read failed"), { code: "EIO" }));
      });
      response.on("error", () => {
        assert.equal(response.statusCode, 200);
        assert.equal(Buffer.concat(chunks).includes("DOWNLOAD_FAILED"), false);
        resolve();
      });
      response.on("end", () => reject(new Error("A truncated response must fail")));
    });
    connection.on("error", reject);
  });
  assert.equal(source.destroyed, true);
});
