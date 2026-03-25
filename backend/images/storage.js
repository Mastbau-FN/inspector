const pathm = require("path");

const files = require("./filesystem");
const rootfolder = require("../db/queries").getLink;

const { memorize_link } = require("./hash");

const fs = require("fs");
const multer = require("multer");
const {
  set_first_image_as_main,
  no_image_placeholder_name,
} = require("../options");

const { decorateDataFromLocalId } = require("../misc/local_id");

const TIMESTAMP_JPG_PATTERN = /^\d{2}_\d{2}_\d{4}_\d{2}_\d{2}_\d{2}\.jpg$/i;

const pad2 = (v) => String(v).padStart(2, "0");

function formatTimestampJpg(date) {
  return `${pad2(date.getDate())}_${pad2(date.getMonth() + 1)}_${date.getFullYear()}_${pad2(date.getHours())}_${pad2(date.getMinutes())}_${pad2(date.getSeconds())}.jpg`;
}

function _sanitizeUploadName(name) {
  if (name == null) return "";
  const normalized = String(name).replace(/\\/g, "/");
  return pathm.basename(normalized).trim();
}

function _extractCanonicalTimestampName(name) {
  const match = String(name).match(/\d{2}_\d{2}_\d{4}_\d{2}_\d{2}_\d{2}\.jpg/i);
  return match ? match[0] : null;
}

function _forceJpgExtension(name) {
  return String(name).replace(/\.[^.]+$/i, ".jpg");
}

function _fallbackTimestampName(fieldname) {
  const asNumber = Number.parseInt(String(fieldname ?? ""), 10);
  if (!Number.isFinite(asNumber)) return null;
  const d = new Date(asNumber);
  if (!Number.isFinite(d.getTime())) return null;
  return formatTimestampJpg(d);
}

function _toPosixPath(input) {
  return String(input ?? "").replace(/\\/g, "/").replace(/\/+/g, "/");
}

function _trimTrailingSlash(input) {
  const s = _toPosixPath(input);
  return s.endsWith("/") ? s.slice(0, -1) : s;
}

function _normalizeLinkForFilesystem(rootfolder, link) {
  const root = _trimTrailingSlash(rootfolder);
  const rawLink = _trimTrailingSlash(link);
  if (!rawLink || rawLink === ".") return "";

  if (!root) return rawLink;
  if (rawLink === root) return "";
  if (rawLink.startsWith(root + "/")) return rawLink.slice(root.length + 1);

  const stripDrive = (p) => p.replace(/^[A-Za-z]:\//, "");
  const rootNoDrive = stripDrive(root);
  const linkNoDrive = stripDrive(rawLink);
  if (linkNoDrive === rootNoDrive) return "";
  if (linkNoDrive.startsWith(rootNoDrive + "/")) {
    return linkNoDrive.slice(rootNoDrive.length + 1);
  }

  return linkNoDrive;
}

function getStoredFilename(file) {
  const clientName = _sanitizeUploadName(file.originalname);
  if (TIMESTAMP_JPG_PATTERN.test(clientName)) return _forceJpgExtension(clientName);

  const embedded = _extractCanonicalTimestampName(clientName);
  if (embedded && TIMESTAMP_JPG_PATTERN.test(embedded)) {
    return _forceJpgExtension(embedded);
  }

  return _fallbackTimestampName(file.fieldname) ?? formatTimestampJpg(new Date());
}

const mstorage = multer.diskStorage({
  //done?: we currently store everything in the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
    const frontendname = _sanitizeUploadName(file.originalname);
    const storedFilename = getStoredFilename(file);
    file.originalname = storedFilename;

    console.info("file uploaded");
    //shouldnt be neccessary, since upload route used fieldparser as middleware
    try {
      //might fail if the body was already parsed
      req.body.data = JSON.parse(req.body.data);
    } catch (_) {}

    try {
      req.body.data = decorateDataFromLocalId(req.body.data);
    } catch (_) {}

    return rootfolder(req.body.data).then((rf) => {
        // console.log("🚀 ~ file: storage.js:29 ~ rootfolder ~ rf", rf)
        
        console.log("multi-upload", rf);
        const fsLink = _normalizeLinkForFilesystem(rf.rootfolder, rf.link);
        const targetPath = files.formatpath(pathm.join(rf.rootfolder, fsLink));
        fs.mkdirSync(targetPath, { recursive: true });
        let prev_filename = rf.filename;

        // compute the hash for the stored filename immediately
        const rfForHash = { ...rf, link: fsLink, filename: file.originalname };
        const hash = memorize_link(rfForHash);
        rf.filename = file.originalname;

        if (!req.__uploaded_images) req.__uploaded_images = [];
        req.__uploaded_images.push({
          client_filename: frontendname,
          stored_filename: file.originalname,
          stored_link: pathm.join(fsLink, file.originalname),
          hash,
        });

        // If destination was empty -> set the new image as main (aka as req.body.Link; update).
        // Defer this until after multer finished and auth/login wall ran, otherwise req.user is not available yet.
        if (
          set_first_image_as_main &&
          (!prev_filename || prev_filename == no_image_placeholder_name) &&
          !req.__pending_set_main_hash
        ) {
          const linkForDb = _toPosixPath(rf.link);
          req.__pending_set_main_link = pathm.join(
            linkForDb,
            file.originalname
          );
          req.__pending_set_main_hash = hash;
        }
        cb(null, targetPath);
    
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
  mstorage,
};
