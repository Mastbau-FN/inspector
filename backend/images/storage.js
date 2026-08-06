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
const logger = require("../misc/logger");

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

function _isDrivePath(input) {
  return /^[A-Za-z]:\//.test(String(input ?? ""));
}

function _normalizeLinkForFilesystem(rootfolder, link) {
  const root = _trimTrailingSlash(rootfolder);
  const rawLink = _trimTrailingSlash(link);
  if (!rawLink || rawLink === ".") return "";

  // Keep absolute filesystem and drive-prefixed links unchanged.
  if (pathm.isAbsolute(rawLink) || _isDrivePath(rawLink)) return rawLink;

  if (!root || root === ".") return rawLink;
  if (rawLink === root) return "";
  if (rawLink.startsWith(root + "/")) return rawLink.slice(root.length + 1);
  return rawLink;
}

function _resolveTargetDirectory(rootfolder, linkForFilesystem) {
  const root = String(rootfolder ?? "").trim();
  const link = String(linkForFilesystem ?? "").trim();
  const pathInput =
    pathm.isAbsolute(link) || _isDrivePath(link)
      ? link
      : pathm.join(root || ".", link);
  return files.formatpath(pathInput);
}

function _newUploadTraceId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function _uploadWarn(req, event, payload = {}) {
  logger.logEvent("warn", "upload", event, req, {
    traceId: req.__upload_trace_id ?? "-",
    ...payload,
  });
}

function _uploadTrace(req, event, payload = {}) {
  logger.logEvent("log", "upload", event, req, {
    traceId: req.__upload_trace_id ?? "-",
    ...payload,
  });
}

function _recordIdentity(data = {}) {
  return {
    originalPjNr: data.PjNr,
    originalE1: data.E1,
    originalE2: data.E2,
    originalE3: data.E3,
    originalLocalId: data.local_id,
    originalParentLocalId: data.parent_local_id,
  };
}

function _isUnresolvedLocalRecord(type, data = {}) {
  const localId = String(data.local_id ?? "");
  const hasLocalId = localId.startsWith("__loc");
  if (!hasLocalId) return false;

  if (type === "defect") return !(Number(data.E3) > 0);
  if (type === "checkpoint") return !(Number(data.E2) > 0);
  if (type === "category") return !(Number(data.E1) > 0);
  return false;
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
    let phase = "initialize";
    if (!req.__upload_trace_id) {
      req.__upload_trace_id = _newUploadTraceId();
    }

    const frontendname = _sanitizeUploadName(file.originalname);
    const storedFilename = getStoredFilename(file);
    file.originalname = storedFilename;

    //shouldnt be neccessary, since upload route used fieldparser as middleware
    if (typeof req.body?.data === "string") {
      phase = "parse-data";
      try {
        //might fail if the body was already parsed
        req.body.data = JSON.parse(req.body.data);
      } catch (e) {
        _uploadWarn(req, "parse-data-failed", {
          reason: e?.message ?? String(e),
        });
      }
    }

    const originalIdentity = _recordIdentity(req.body?.data);
    _uploadTrace(req, "file-received", {
      ...originalIdentity,
      field: file.fieldname,
      clientFilename: frontendname,
      storedFilename,
      mimeType: file.mimetype,
      encoding: file.encoding,
    });

    if (_isUnresolvedLocalRecord(req.body?.type, req.body?.data)) {
      _uploadWarn(req, "unresolved-local-record", {
        ...originalIdentity,
        message: "upload references a locally created record without a positive server id",
      });
    }

    phase = "decorate-local-id";
    try {
      req.body.data = decorateDataFromLocalId(req.body.data);
    } catch (e) {
      _uploadWarn(req, "decorate-local-id-failed", {
        ...logger.errorContext(e),
      });
    }

    phase = "resolve-target";
    _uploadTrace(req, "target-resolution-started", {
      ...originalIdentity,
      resolvedPjNr: req.body?.data?.PjNr,
      resolvedE1: req.body?.data?.E1,
      resolvedE2: req.body?.data?.E2,
      resolvedE3: req.body?.data?.E3,
    });
    return rootfolder(req.body.data).then((rf) => {
        phase = "prepare-target-directory";
        const fsLink = _normalizeLinkForFilesystem(rf.rootfolder, rf.link);
        const targetPath = _resolveTargetDirectory(rf.rootfolder, fsLink);
        const targetFilePath = pathm.join(targetPath, file.originalname);

        _uploadTrace(req, "target-resolved", {
          rootfolder: rf.rootfolder,
          rawLink: rf.link,
          normalizedLink: fsLink,
          previousFilename: rf.filename,
          targetDirectory: targetPath,
          targetFile: targetFilePath,
        });

        fs.mkdirSync(targetPath, { recursive: true });
        let prev_filename = rf.filename;

        // compute the hash for the stored filename immediately
        phase = "create-hash";
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
        phase = "multer-write";
        cb(null, targetPath);
    
    }).catch((error) => {
      _uploadWarn(req, "destination-error", {
        phase,
        ...logger.errorContext(error),
      });
      cb(error);
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
  mstorage,
};
