const assert = require("node:assert/strict");
const { execFile } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { promisify } = require("node:util");

const run = promisify(execFile);
const script = path.join(__dirname, "cleanup-metadata.js");

test("metadata cleanup requires explicit directories", async () => {
  await assert.rejects(run(process.execPath, [script]), (error) => {
    assert.equal(error.code, 1);
    assert.match(error.stderr, /Usage:/);
    return true;
  });
});

test("metadata cleanup is explicit, non-recursive and leaves symlinks untouched", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-cleanup-cli-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  await fs.writeFile(path.join(directory, "Thumbs.db"), "metadata");
  await fs.writeFile(path.join(directory, "report.pdf"), "document");
  await fs.mkdir(path.join(directory, "nested"));
  await fs.writeFile(path.join(directory, "nested", "Thumbs.db"), "nested metadata");
  await fs.symlink(path.join(directory, "report.pdf"), path.join(directory, ".DS_Store"));
  const { stdout } = await run(process.execPath, [script, directory]);
  assert.deepEqual(JSON.parse(stdout).removed, [path.join(directory, "Thumbs.db")]);
  assert.equal(await fs.readFile(path.join(directory, "report.pdf"), "utf8"), "document");
  assert.equal(await fs.readFile(path.join(directory, "nested", "Thumbs.db"), "utf8"), "nested metadata");
  assert.equal((await fs.lstat(path.join(directory, ".DS_Store"))).isSymbolicLink(), true);
});

test("metadata cleanup returns a failure exit code but continues with later directories", async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-cleanup-cli-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  await fs.writeFile(path.join(directory, "desktop.ini"), "metadata");
  await assert.rejects(run(process.execPath, [script, path.join(directory, "missing"), directory]), (error) => {
    assert.equal(error.code, 1);
    assert.match(error.stderr, /Cleanup failed/);
    return true;
  });
  assert.deepEqual(await fs.readdir(directory), []);
});
