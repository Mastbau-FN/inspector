const fs = require("fs");
const fsp = fs.promises;

const pathm = require("path");

const root_path = process.env.IMG_ROOT_PATH; //might be needed when mounting network drives locally

///removes the drive and replaces it with our given root path
const formatpath = (path) => {
  const parts = path.split(pathm.sep);
  const drive = parts.shift()[0];
  path = pathm.join(root_path, drive, ...parts);
  return path;
};

const getImageFrom = (rootpath, link, filename) =>
  fsp.readFile(formatpath(pathm.join(rootpath, link, filename)));

const _getAllImagenamesFromPath = async (path) => {
  path = formatpath(path);

  const dirents = await fsp.readdir(path, { withFileTypes: true });
  return dirents
    .filter((dirent) => dirent.isFile())
    .map((dirent) => dirent.name);
};

const getAllImagenamesFrom = async (rootpath, link) => {
  try {
    return await _getAllImagenamesFromPath(pathm.join(rootpath, link));
  } catch (e) {
    console.warn("failed to get image names: ", e);
    return [];
  }
};

module.exports = {
  getAllImagenamesFrom,
  getImageFrom,
  formatpath,
};
