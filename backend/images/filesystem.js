const fs = require("fs");
const fsp = fs.promises;

const pathm = require("path");

const root_path = process.env.IMG_ROOT_PATH; //might be needed when mounting network drives locally, dont forget to also mount the correct drives in docker-compose

class StorageUnavailableError extends Error {
  constructor(cause) {
    super("File storage is unavailable", { cause });
    this.code = "STORAGE_UNAVAILABLE";
  }
}

const fileError = (code, message) => Object.assign(new Error(message), { code });

const systemMetadataFilenames = new Set([
  "thumbs.db",
  "ehthumbs.db",
  "ehthumbs_vista.db",
  "desktop.ini",
  ".ds_store",
]);

const isSystemMetadataFilename = (filename) =>
  systemMetadataFilenames.has(pathm.basename(String(filename ?? "")).trim().toLowerCase());

const removeSystemMetadataFilesFromDirectory = async (directoryPath) => {
  const formattedPath = formatpath(directoryPath);
  const dirents = await fsp.readdir(formattedPath, { withFileTypes: true });
  const removedFiles = [];
  const failures = [];

  for (const dirent of dirents) {
    if (!dirent.isFile() || !isSystemMetadataFilename(dirent.name)) continue;

    const filePath = pathm.join(formattedPath, dirent.name);
    try {
      await fsp.unlink(filePath);
      removedFiles.push(filePath);
    } catch (error) {
      if (error.code !== "ENOENT") failures.push(error);
    }
  }

  if (failures.length > 0) {
    throw new AggregateError(failures, "Some system metadata files could not be deleted");
  }
  return removedFiles;
};

///removes the drive and replaces it with our given root path
const formatpath = (path) => {
  const raw = String(path ?? "").replace(/\\/g, "/").trim();
  if (raw.length === 0) return raw;

  // Absolute linux paths should stay untouched.
  if (raw.startsWith("/")) {
    return pathm.normalize(raw);
  }

  // Handle windows-drive style locations: "S:/x", "S:x", or "S/x".
  const driveWithColon = raw.match(/^([A-Za-z]):\/?(.*)$/);
  if (driveWithColon) {
    const drive = driveWithColon[1];
    const tail = (driveWithColon[2] ?? "")
      .split("/")
      .filter((p) => p.length > 0);
    return pathm.join(root_path ?? "", drive, ...tail);
  }

  const parts = raw.split("/").filter((p) => p.length > 0);
  if (parts.length > 0 && /^[A-Za-z]$/.test(parts[0])) {
    const drive = parts.shift();
    return pathm.join(root_path ?? "", drive, ...parts);
  }

  // Fallback for regular relative paths.
  if (root_path && root_path.length > 0) {
    return pathm.join(root_path, raw);
  }
  return pathm.normalize(raw);
};

const openFileStream = async (filePath) => {
  const handle = await fsp.open(
    filePath,
    fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK,
  );
  try {
    const stat = await handle.stat();
    if (!stat.isFile()) throw fileError("NOT_A_FILE", "Expected a regular file");
    return { stream: handle.createReadStream(), size: stat.size };
  } catch (error) {
    await handle.close();
    throw error;
  }
};

const getImageFrom = async (rootpath, link, filename) => {
  const directory = formatpath(pathm.join(rootpath, link));
  try {
    return await openFileStream(pathm.join(directory, filename));
  } catch (error) {
    if (error.code === "ENOENT") {
      try {
        await fsp.stat(directory);
      } catch (directoryError) {
        throw new StorageUnavailableError(directoryError);
      }
    }
    throw error;
  }
};

const _getAllImagenamesFromPath = async (path) => {
  path = formatpath(path);

  const dirents = await fsp.readdir(path, { withFileTypes: true });
  return dirents
    .filter((dirent) => dirent.isFile() && !isSystemMetadataFilename(dirent.name))
    .map((dirent) => dirent.name);
};


const getAllImagenamesFrom = async (rootpath, link) => {
  try {
    return await _getAllImagenamesFromPath(pathm.join(rootpath, link));
  } catch (error) {
    throw new StorageUnavailableError(error);
  }
};

const getDocumentsFrom = async (baseDirectory) => {
  const basePath = formatpath(baseDirectory);
  const documentPath = pathm.join(basePath, "Dokus");
  try {
    if ((await fsp.lstat(documentPath)).isSymbolicLink()) {
      throw fileError("FORBIDDEN_PATH", "Document directory must not be a symbolic link");
    }
    const filenames = await _getAllImagenamesFromPath(documentPath);
    return {
      DokusPath: documentPath,
      DokusPaths: filenames.map((filename) => ({
        filename,
        docupath: pathm.join(documentPath, filename),
      })),
    };
  } catch (error) {
    if (error.code === "ENOENT") {
      try {
        const baseStat = await fsp.stat(basePath);
        if (!baseStat.isDirectory()) throw error;
        return { DokusPath: null, DokusPaths: [] };
      } catch (baseError) {
        throw new StorageUnavailableError(baseError);
      }
    }
    throw new StorageUnavailableError(error);
  }
};

const isWithinDirectory = (directory, candidate) => {
  const relative = pathm.relative(directory, candidate);
  return relative !== ".." && !relative.startsWith(`..${pathm.sep}`) && !pathm.isAbsolute(relative);
};

const getDocumentFrom = async (docPath, filename, allowedDirectories) => {
  if (typeof docPath !== "string" || !docPath.trim() || docPath.includes("\0")) {
    throw fileError("INVALID_PATH", "A document path is required");
  }
  if (docPath.replace(/\\/g, "/").split("/").includes("..")) {
    throw fileError("FORBIDDEN_PATH", "Document path is not allowed");
  }
  if (filename != null && (
    typeof filename !== "string" || !filename.trim() ||
    filename === "." || filename === ".." || /[\\/\0]/.test(filename)
  )) {
    throw fileError("INVALID_PATH", "Expected a filename without a directory");
  }

  let candidate = pathm.resolve(formatpath(docPath));
  const directory = allowedDirectories
    .map((allowed) => pathm.resolve(formatpath(allowed)))
    .find((allowed) => isWithinDirectory(allowed, candidate));
  if (!directory) throw fileError("FORBIDDEN_PATH", "Document path is not allowed");

  let realDirectory;
  try {
    if ((await fsp.lstat(directory)).isSymbolicLink()) {
      throw fileError("FORBIDDEN_PATH", "Document directory must not be a symbolic link");
    }
    realDirectory = await fsp.realpath(directory);
  } catch (error) {
    if (error.code === "FORBIDDEN_PATH") throw error;
    throw new StorageUnavailableError(error);
  }
  if ((await fsp.stat(candidate)).isDirectory()) {
    if (filename == null) throw fileError("INVALID_PATH", "A filename is required for a directory");
    candidate = pathm.join(candidate, filename);
  }
  const realFile = await fsp.realpath(candidate);
  if (!isWithinDirectory(realDirectory, realFile) || isSystemMetadataFilename(realFile)) {
    throw fileError("FORBIDDEN_PATH", "Document path is not allowed");
  }
  return openFileStream(realFile);
};

module.exports = {
  StorageUnavailableError,
  getAllImagenamesFrom,
  getDocumentsFrom,
  getDocumentFrom,
  getImageFrom,
  formatpath,
  isSystemMetadataFilename,
  removeSystemMetadataFilesFromDirectory,
};
