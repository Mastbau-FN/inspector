const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const queries = require("./queries");
const pool = require("./pool").db.pool;
const imageFilesystem = require("../images/filesystem");

test("allowed document directories come from the authenticated user's inspection query", async (context) => {
  const queryMock = context.mock.method(pool, "asyncQuery", async (sql, parameters) => {
    if (sql.includes("ANY")) {
      assert.deepEqual(parameters, [[123]]);
      return { rows: [] };
    }
    assert.match(sql, /"MGAUFTR"\."Bauleitung" = \$1/);
    assert.deepEqual(parameters, ["TEST", 2000, 1910]);
    return { rows: [
      { PjNr: 123, LinkOrdner: "/srv/inspections/assigned" },
      { PjNr: 123, LinkOrdner: "/srv/inspections/assigned" },
      { PjNr: 123, LinkOrdner: null, Link: null },
    ] };
  });
  assert.deepEqual(await queries.getDocumentDirectoriesForUser({ KZL: "TEST" }), ["/srv/inspections/assigned/Dokus"]);
  assert.equal(queryMock.mock.callCount(), 2);
});

test("assigned tree documents are downloadable without granting other project files", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-document-tree-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  const roots = ["inspection", "category", "checkpoint", "defect"].map((name) => path.join(directory, name));
  for (const root of roots) {
    await fs.mkdir(path.join(root, "Dokus"), { recursive: true });
    await fs.writeFile(path.join(root, "Dokus", "report.pdf"), "assigned document");
  }
  await fs.writeFile(path.join(roots[0], "private.txt"), "not a document");
  const unassigned = path.join(directory, "unassigned", "Dokus");
  await fs.mkdir(unassigned, { recursive: true });
  await fs.writeFile(path.join(unassigned, "report.pdf"), "other user's document");
  context.mock.method(pool, "asyncQuery", async (sql, parameters) => {
    if (sql.includes('"MGAUFTR"')) {
      assert.deepEqual(parameters, ["TEST", 2000, 1910]);
      return { rows: [{ PjNr: 123, LinkOrdner: roots[0] }] };
    }
    assert.match(sql, /"PjNr"\s*=\s*ANY\(\$1::integer\[\]\)/);
    assert.match(sql, /"EREArt" IN \(5100, 5200, 5201, 5202, 5203, 5204\)/);
    assert.deepEqual(parameters, [[123]]);
    return { rows: roots.slice(1).map((root) => ({ PjNr: 123, LinkOrdner: root })) };
  });
  const allowed = await queries.getDocumentDirectoriesForUser({ KZL: "TEST" });
  for (const root of roots) {
    const download = await imageFilesystem.getDocumentFrom(path.join(root, "Dokus", "report.pdf"), undefined, allowed);
    const chunks = [];
    for await (const chunk of download.stream) chunks.push(chunk);
    assert.equal(Buffer.concat(chunks).toString(), "assigned document");
  }
  for (const forbidden of [path.join(roots[0], "private.txt"), path.join(unassigned, "report.pdf")]) {
    await assert.rejects(imageFilesystem.getDocumentFrom(forbidden, undefined, allowed), { code: "FORBIDDEN_PATH" });
  }
});

test("no assigned inspections grant no child document roots", async (context) => {
  const queryMock = context.mock.method(pool, "asyncQuery", async (sql) => {
    assert.match(sql, /"MGAUFTR"/);
    return { rows: [] };
  });
  assert.deepEqual(await queries.getDocumentDirectoriesForUser({ KZL: "TEST" }), []);
  assert.equal(queryMock.mock.callCount(), 1);
});

test("missing authenticated identity grants no document directories and makes no query", async (context) => {
  const queryMock = context.mock.method(pool, "asyncQuery", () => { throw new Error("No query expected"); });
  assert.deepEqual(await queries.getDocumentDirectoriesForUser(undefined), []);
  assert.deepEqual(await queries.getDocumentDirectoriesForUser({}), []);
  assert.equal(queryMock.mock.callCount(), 0);
});

test("legacy document directories use server-side links without updating the database", async (context) => {
  const queryMock = context.mock.method(pool, "asyncQuery", async (sql, parameters) => {
    assert.doesNotMatch(sql, /UPDATE/);
    if (sql.includes("ANY")) {
      assert.deepEqual(parameters, [[123]]);
      return { rows: [] };
    }
    if (sql.includes('"MGAUFTR"')) {
      assert.equal(parameters[0], "TEST");
      return { rows: [{ PjNr: 123, Link: "project/photo.jpg" }] };
    }
    assert.deepEqual(parameters, [123, 1910]);
    return { rows: [{ firstNonNull: () => "/srv/inspections/main.jpg" }] };
  });
  assert.deepEqual(await queries.getDocumentDirectoriesForUser({ KZL: "TEST" }), ["/srv/inspections/project/Dokus"]);
  assert.equal(queryMock.mock.callCount(), 3);
});

test("inspection hydration lists documents without cleanup or synchronous filesystem calls", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-queries-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  await fs.mkdir(path.join(directory, "Dokus"));
  await fs.writeFile(path.join(directory, "Dokus", "report.pdf"), "document");
  await fs.writeFile(path.join(directory, "Dokus", "Thumbs.db"), "metadata");
  await fs.writeFile(path.join(directory, "photo.jpg"), "image");
  context.mock.method(pool, "asyncQuery", async () => ({ rows: [{ PjNr: 123, LinkOrdner: directory, Link: "photo.jpg" }] }));
  context.mock.method(imageFilesystem, "removeSystemMetadataFilesFromDirectory", () => { throw new Error("Listings must not delete files"); });
  const nativeFs = require("node:fs");
  for (const method of ["existsSync", "lstatSync", "readdirSync", "statSync"]) {
    context.mock.method(nativeFs, method, () => { throw new Error("Listings must be asynchronous"); });
  }
  const rows = await queries.getInspectionsForUser({ KZL: "TEST" });
  const result = await rows.hashImagesAndCreateIds();
  assert.deepEqual(result[0].DokusPaths, [{ filename: "report.pdf", docupath: path.join(directory, "Dokus", "report.pdf") }]);
  assert.equal(typeof result[0].mainhash, "string");
  assert.equal(await fs.readFile(path.join(directory, "Dokus", "Thumbs.db"), "utf8"), "metadata");
});

test("inspection hydration propagates missing storage instead of publishing empty images", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-unavailable-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  context.mock.method(pool, "asyncQuery", async () => ({ rows: [{ PjNr: 123, LinkOrdner: path.join(directory, "missing") }] }));
  const rows = await queries.getInspectionsForUser({ KZL: "TEST" });
  await assert.rejects(rows.hashImagesAndCreateIds(), { code: "STORAGE_UNAVAILABLE" });
});
