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

function _resolveTargetDirectory(rootfolder, linkForFilesystem) {
  const root = String(rootfolder ?? "").trim();
  const link = String(linkForFilesystem ?? "").trim();
  const pathInput = pathm.isAbsolute(link) ? link : pathm.join(root || ".", link);
  return files.formatpath(pathInput);
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
        console.log("multi-upload", {
          rootfolder: rf?.rootfolder,
          link: rf?.link,
          existing_main_filename: rf?.filename,
          incoming_client_filename: frontendname,
          incoming_stored_filename: storedFilename,
        });
        const fsLink = _normalizeLinkForFilesystem(rf.rootfolder, rf.link);
        const targetPath = _resolveTargetDirectory(rf.rootfolder, fsLink);
        const targetFilePath = pathm.join(targetPath, file.originalname);
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
          stored_rootfolder: rf.rootfolder,
          stored_link_raw: rf.link,
          stored_link_normalized: fsLink,
          stored_directory_path: targetPath,
          stored_absolute_path: targetFilePath,
          hash,
        });

        try {
          console.log(
            "[upload-trace] destination-resolved",
            JSON.stringify(
              {
                client_filename: frontendname,
                stored_filename: file.originalname,
                data_scope: {
                  PjNr: req?.body?.data?.PjNr,
                  E1: req?.body?.data?.E1,
                  E2: req?.body?.data?.E2,
                  E3: req?.body?.data?.E3,
                },
                rootfolder: rf.rootfolder,
                link_raw: rf.link,
                link_normalized: fsLink,
                existing_main_filename: prev_filename,
                target_directory: targetPath,
                target_directory_is_absolute: pathm.isAbsolute(targetPath),
                target_file: targetFilePath,
                exists_before_write: fs.existsSync(targetFilePath),
              },
              null,
              2
            )
          );
        } catch (_) {}

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
