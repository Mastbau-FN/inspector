const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const imageFilesystem = require("./filesystem");

test("removes system metadata files from a document directory", async (t) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "doku-cleanup-"));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));

  await Promise.all([
    fs.writeFile(path.join(directory, "Thumbs.db"), "metadata"),
    fs.writeFile(path.join(directory, ".DS_Store"), "metadata"),
    fs.writeFile(path.join(directory, "Pruefplan.pdf"), "document"),
    fs.mkdir(path.join(directory, "Thumbs.db.backup")),
  ]);

  const removed = await imageFilesystem.removeSystemMetadataFilesFromDirectory(
    directory,
  );

  assert.deepEqual(
    removed.map((filePath) => path.basename(filePath)).sort(),
    [".DS_Store", "Thumbs.db"],
  );
  assert.deepEqual(
    (await fs.readdir(directory)).sort(),
    ["Pruefplan.pdf", "Thumbs.db.backup"],
  );
});
