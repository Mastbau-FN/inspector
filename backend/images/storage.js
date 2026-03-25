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
        const targetPath = files.formatpath(pathm.join(rf.rootfolder, rf.link));
        fs.mkdirSync(targetPath, { recursive: true });
        let prev_filename = rf.filename;

        // compute the hash for the stored filename immediately
        const rfForHash = { ...rf, filename: file.originalname };
        const hash = memorize_link(rfForHash);
        rf.filename = file.originalname;

        if (!req.__uploaded_images) req.__uploaded_images = [];
        req.__uploaded_images.push({
          client_filename: frontendname,
          stored_filename: file.originalname,
          hash,
        });

        // If destination was empty -> set the new image as main (aka as req.body.Link; update).
        // Defer this until after multer finished and auth/login wall ran, otherwise req.user is not available yet.
        if (
          set_first_image_as_main &&
          (!prev_filename || prev_filename == no_image_placeholder_name) &&
          !req.__pending_set_main_hash
        ) {
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
