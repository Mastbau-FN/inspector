const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

process.env.IMG_ROOT_PATH = path.join(os.tmpdir(), "inspector-path-tests");
const imageFilesystem = require("./filesystem");

const temporaryDirectory = async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "doku-cleanup-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  return directory;
};

const readDownload = async ({ stream, size }) => {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  const contents = Buffer.concat(chunks);
  assert.equal(contents.length, size);
  return contents.toString();
};

const storageErrorWithCause = (code) => (error) => {
  assert.equal(error.code, "STORAGE_UNAVAILABLE");
  assert.equal(error.cause.code, code);
  return true;
};

test("removes system metadata files from a document directory", async (context) => {
  const directory = await temporaryDirectory(context);

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

test("formats Windows, mapped-drive, relative and absolute paths", () => {
  const expected = path.join(process.env.IMG_ROOT_PATH, "S", "Projekt", "Fotos");
  for (const input of ["S:\\Projekt\\Fotos", "S:/Projekt/Fotos", "S:Projekt/Fotos", "S/Projekt/Fotos", " S://Projekt//Fotos "]) {
    assert.equal(imageFilesystem.formatpath(input), expected);
  }
  assert.equal(imageFilesystem.formatpath("Projekt/Fotos"), path.join(process.env.IMG_ROOT_PATH, "Projekt", "Fotos"));
  assert.equal(imageFilesystem.formatpath("/srv/photos/./project"), "/srv/photos/project");
  assert.equal(imageFilesystem.formatpath(null), "");
  assert.equal(imageFilesystem.formatpath(" "), "");
});

test("recognizes metadata names case-insensitively without matching real documents", () => {
  for (const name of ["Thumbs.db", "ehthumbs.db", "ehthumbs_vista.db", "DESKTOP.INI", ".DS_Store"]) {
    assert.equal(imageFilesystem.isSystemMetadataFilename(name), true);
  }
  for (const name of ["Thumbs.db.pdf", "report.pdf", "photo.jpg", null]) {
    assert.equal(imageFilesystem.isSystemMetadataFilename(name), false);
  }
});

test("an empty image directory returns an empty list", async (context) => {
  const directory = await temporaryDirectory(context);
  assert.deepEqual(await imageFilesystem.getAllImagenamesFrom(directory, ""), []);
});

test("image listings ignore metadata, directories and symlinks", async (context) => {
  const directory = await temporaryDirectory(context);
  await fs.writeFile(path.join(directory, "photo.jpg"), "photo");
  await fs.writeFile(path.join(directory, "Thumbs.db"), "metadata");
  await fs.mkdir(path.join(directory, "Dokus"));
  await fs.symlink(path.join(directory, "photo.jpg"), path.join(directory, "linked.jpg"));
  assert.deepEqual(await imageFilesystem.getAllImagenamesFrom(directory, ""), ["photo.jpg"]);
});

test("missing image directories are errors, not empty listings", async (context) => {
  const directory = await temporaryDirectory(context);
  await assert.rejects(imageFilesystem.getAllImagenamesFrom(directory, "missing"), storageErrorWithCause("ENOENT"));
});

for (const code of ["EACCES", "EIO", "ESTALE", "ETIMEDOUT"]) {
  test(`image and document listings preserve ${code} as a storage error`, async (context) => {
    const directory = await temporaryDirectory(context);
    await fs.mkdir(path.join(directory, "Dokus"));
    context.mock.method(fs, "readdir", async () => {
      throw Object.assign(new Error("Simulated storage error"), { code });
    });
    await assert.rejects(imageFilesystem.getAllImagenamesFrom(directory, ""), storageErrorWithCause(code));
    await assert.rejects(imageFilesystem.getDocumentsFrom(directory), storageErrorWithCause(code));
  });
}

test("document listings are read-only and keep their API shape", async (context) => {
  const directory = await temporaryDirectory(context);
  const documents = path.join(directory, "Dokus");
  await fs.mkdir(documents);
  await fs.writeFile(path.join(documents, "report.pdf"), "document");
  await fs.writeFile(path.join(documents, ".DS_Store"), "metadata");
  assert.deepEqual(await imageFilesystem.getDocumentsFrom(directory), {
    DokusPath: documents,
    DokusPaths: [{ filename: "report.pdf", docupath: path.join(documents, "report.pdf") }],
  });
  assert.equal(await fs.readFile(path.join(documents, ".DS_Store"), "utf8"), "metadata");
});

test("a missing optional Dokus directory differs from a missing parent", async (context) => {
  const directory = await temporaryDirectory(context);
  assert.deepEqual(await imageFilesystem.getDocumentsFrom(directory), { DokusPath: null, DokusPaths: [] });
  await assert.rejects(imageFilesystem.getDocumentsFrom(path.join(directory, "missing")), { code: "STORAGE_UNAVAILABLE" });
  await fs.writeFile(path.join(directory, "Dokus"), "not a directory");
  await assert.rejects(imageFilesystem.getDocumentsFrom(directory), { code: "STORAGE_UNAVAILABLE" });
});

test("documents support full paths and directory plus filename", async (context) => {
  const directory = await temporaryDirectory(context);
  const filePath = path.join(directory, "report.pdf");
  await fs.writeFile(filePath, "document contents");
  for (const [docPath, filename] of [[filePath, undefined], [directory, "report.pdf"], [filePath.replaceAll("/", "\\"), undefined]]) {
    assert.equal(await readDownload(await imageFilesystem.getDocumentFrom(docPath, filename, [directory])), "document contents");
  }
});

test("documents reject traversal, other roots and lookalike prefixes", async (context) => {
  const directory = await temporaryDirectory(context);
  const documents = path.join(directory, "Dokus");
  await fs.mkdir(documents);
  await fs.writeFile(path.join(directory, "private.txt"), "secret");
  for (const candidate of [
    `${documents}/../private.txt`, `${documents}\\..\\private.txt`,
    path.join(directory, "private.txt"), `${documents}-other/report.pdf`,
  ]) {
    await assert.rejects(imageFilesystem.getDocumentFrom(candidate, undefined, [documents]), { code: "FORBIDDEN_PATH" });
  }
  await assert.rejects(imageFilesystem.getDocumentFrom(path.join(documents, "report.pdf"), undefined, []), { code: "FORBIDDEN_PATH" });
});

test("documents reject missing paths and unsafe filenames", async (context) => {
  const directory = await temporaryDirectory(context);
  for (const docPath of [undefined, null, 42, {}, "", "\0", "   "]) {
    await assert.rejects(imageFilesystem.getDocumentFrom(docPath, undefined, [directory]), { code: "INVALID_PATH" });
  }
  for (const filename of ["..", ".", "", "../private.txt", "..\\private.txt", "/private.txt", "bad\0.pdf", {}]) {
    await assert.rejects(imageFilesystem.getDocumentFrom(directory, filename, [directory]), { code: "INVALID_PATH" });
  }
  await assert.rejects(imageFilesystem.getDocumentFrom(directory, undefined, [directory]), { code: "INVALID_PATH" });
});

test("documents reject symlinks escaping through a file or subdirectory", async (context) => {
  const directory = await temporaryDirectory(context);
  const documents = path.join(directory, "Dokus");
  const outside = path.join(directory, "outside");
  await fs.mkdir(documents);
  await fs.mkdir(outside);
  await fs.writeFile(path.join(outside, "secret.pdf"), "secret");
  await fs.symlink(path.join(outside, "secret.pdf"), path.join(documents, "link.pdf"));
  await fs.symlink(outside, path.join(documents, "linked-directory"));
  for (const candidate of [path.join(documents, "link.pdf"), path.join(documents, "linked-directory", "secret.pdf")]) {
    await assert.rejects(imageFilesystem.getDocumentFrom(candidate, undefined, [documents]), { code: "FORBIDDEN_PATH" });
  }
});

test("missing documents differ from unavailable allowed directories", async (context) => {
  const directory = await temporaryDirectory(context);
  await assert.rejects(imageFilesystem.getDocumentFrom(path.join(directory, "missing.pdf"), undefined, [directory]), { code: "ENOENT" });
  const missingDirectory = path.join(directory, "missing");
  await assert.rejects(imageFilesystem.getDocumentFrom(path.join(missingDirectory, "report.pdf"), undefined, [missingDirectory]), { code: "STORAGE_UNAVAILABLE" });
});

test("a symlink replacing Dokus cannot expand the allowed document root", async (context) => {
  const directory = await temporaryDirectory(context);
  const outside = path.join(directory, "private");
  const documents = path.join(directory, "Dokus");
  await fs.mkdir(outside);
  await fs.writeFile(path.join(outside, "secret.pdf"), "secret");
  await fs.symlink(outside, documents);
  await assert.rejects(imageFilesystem.getDocumentsFrom(directory), { code: "STORAGE_UNAVAILABLE" });
  await assert.rejects(imageFilesystem.getDocumentFrom(path.join(documents, "secret.pdf"), undefined, [documents]), { code: "FORBIDDEN_PATH" });
});

test("metadata and directories cannot be downloaded as documents", async (context) => {
  const directory = await temporaryDirectory(context);
  await fs.writeFile(path.join(directory, "Thumbs.db"), "metadata");
  await fs.mkdir(path.join(directory, "subdirectory"));
  await assert.rejects(imageFilesystem.getDocumentFrom(path.join(directory, "Thumbs.db"), undefined, [directory]), { code: "FORBIDDEN_PATH" });
  await assert.rejects(imageFilesystem.getDocumentFrom(directory, "subdirectory", [directory]), { code: "NOT_A_FILE" });
});

test("images return a bounded stream, not a complete file buffer", async (context) => {
  const directory = await temporaryDirectory(context);
  const contents = Buffer.alloc(512 * 1024, 123);
  await fs.writeFile(path.join(directory, "photo.jpg"), contents);
  const download = await imageFilesystem.getImageFrom(directory, "", "photo.jpg");
  assert.equal(Buffer.isBuffer(download), false);
  assert.equal(download.size, contents.length);
  assert.ok(download.stream.readableHighWaterMark < contents.length);
  const chunks = [];
  for await (const chunk of download.stream) chunks.push(chunk);
  assert.ok(chunks.length > 1);
  assert.deepEqual(Buffer.concat(chunks), contents);
  assert.equal(download.stream.closed, true);
});

test("missing images differ from unavailable image directories", async (context) => {
  const directory = await temporaryDirectory(context);
  await assert.rejects(imageFilesystem.getImageFrom(directory, "", "missing.jpg"), { code: "ENOENT" });
  await assert.rejects(imageFilesystem.getImageFrom(directory, "missing", "photo.jpg"), { code: "STORAGE_UNAVAILABLE" });
});

test("cleanup reports permission failures without deleting normal files", async (context) => {
  const directory = await temporaryDirectory(context);
  await fs.writeFile(path.join(directory, "Thumbs.db"), "metadata");
  await fs.writeFile(path.join(directory, "report.pdf"), "document");
  context.mock.method(fs, "unlink", async () => {
    throw Object.assign(new Error("Permission denied"), { code: "EACCES" });
  });
  await assert.rejects(imageFilesystem.removeSystemMetadataFilesFromDirectory(directory), AggregateError);
  assert.equal(await fs.readFile(path.join(directory, "report.pdf"), "utf8"), "document");
});
