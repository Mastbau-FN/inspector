const fs = require("fs");
const fsp = fs.promises;

const pathm = require("path");

const root_path = process.env.IMG_ROOT_PATH; //might be needed when mounting network drives locally, dont forget to also mount the correct drives in docker-compose

const systemMetadataFilenames = new Set([
  "thumbs.db",
  "ehthumbs.db",
  "ehthumbs_vista.db",
  "desktop.ini",
  ".ds_store",
]);

const isSystemMetadataFilename = (filename) =>
  systemMetadataFilenames.has(pathm.basename(String(filename ?? "")).trim().toLowerCase());

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

const getImageFrom = (rootpath, link, filename) => {
  let pathname = formatpath(pathm.join(rootpath, link, filename));
  //console.log("serving: "+pathname);

  return fsp.readFile(pathname);}

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
  } catch (e) {
    // console.warn("failed to get image names: ", e);
    return [];
  }
};


module.exports = {
  getAllImagenamesFrom,
  getImageFrom,
  formatpath,
  isSystemMetadataFilename,
};
