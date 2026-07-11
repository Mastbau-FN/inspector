const queries = require("./db/queries");
const location = require("./extern/location");

const imghasher = require("./images/hash");
const imgfiler = require("./images/filesystem");
const path = require("path");
const options = require("./options");

const fs = require("fs");
const fsp = fs.promises;
const identifiers = require("./misc/identifiers").identifiers;

function _shortPayload(payload = {}) {
  const out = [];
  for (const [k, v] of Object.entries(payload)) {
    if (v == null) continue;
    if (typeof v === "object") continue;
    out.push(`${k}=${v}`);
  }
  return out.join(" ");
}

function _logRequest(level, req, event, payload = {}) {
  const logger = console[level] ?? console.log;
  const details = _shortPayload(payload);
  logger(
    `[backend] ${event} ${req.method} ${req.originalUrl ?? req.url} req=${req.__request_id ?? "-"}${details ? ` ${details}` : ""}`
  );
}

function _uploadTrace(req, event, payload = {}) {
  const details = _shortPayload(payload);
  console.log(
    `[upload] ${event} req=${req.__request_id ?? "-"} trace=${req.__upload_trace_id ?? "-"}${details ? ` ${details}` : ""}`
  );
}

function _uploadWarn(req, event, payload = {}) {
  const details = _shortPayload(payload);
  console.warn(
    `[upload] WARN ${event} req=${req.__request_id ?? "-"} trace=${req.__upload_trace_id ?? "-"}${details ? ` ${details}` : ""}`
  );
}

//errorhandling
/**
 * 
 * @param {Promise} statement the Promise to await whose result will be parsed by jsonmaker
 * @param {Function} jsonmaker parses the result of the statement to json
 * @param {*} res the express resolve object
 * @param {*} next the express next middleware object (used for error-handling)
 * @returns 
 */
const errsafejson = async (statement, jsonmaker, res, next) => {
  try {
    const val = await statement();
    const jsonderulo = await jsonmaker(val);
    if (!res.headersSent) return res.status(200).json(jsonderulo);
  } catch (error) {
    console.warn(`[backend] errsafejson-failed ${res?.req?.method ?? "-"} ${res?.req?.originalUrl ?? res?.req?.url ?? "-"} reason=${error?.message ?? String(error)}`);
    return next({ error: { errsafejson_captured: error.toString() } });
  }
};

/**
 * simply resolves with success that the user in the req was succesfully logged in
 * this doesnt really do anything besides that but it runs after the user-auth middleware so it only runs if the user credentials are valid
 * @param {*} req express obj
 * @param {*} res express obj
 */
const login = (req, res) => {
  let json_response = { success: true };
  const defLoginId =
    req.user?.Def_Login_ID ??
    req.user?.def_login_id ??
    req.user?.Login_ID_Pruefer ??
    req.user?.login_id_pruefer ??
    null;
  json_response.user = { ...req.user, Def_Login_ID: defLoginId };
  res.status(200).json(json_response);
};

/**
 * resolves all available workers for the pre-login dropdown
 */
const getLoginUsers = (req, res, next) =>
  errsafejson(
    async () => await queries.getLoginUsers(),
    (rows) => ({ users: rows }),
    res,
    next
  );

/**
 * resolves all projects / inspections / locations for the currently logged-in user 
 */
const getProjects = (req, res, next) =>
  errsafejson(
    async () => {
      const inspections = await queries.getInspectionsForUser(req.user);

      
      let processedData = await (async (_x) => { 
        let x = await _x;
        return options.useReverseLocationAPI ? await location.addCoords(x) : x;
      })(inspections.hashImagesAndCreateIds());
      return processedData;
    },
    async (x) => {
      var ret = {};
      ret[`${identifiers.location}s`] = x;
      return ret;
    },
    res,
    next
  );


/**
 * resolves all categories for the current location (given by req.body.PrNr)
 */
const getCategories = (req, res, next) =>
  errsafejson(
    async () =>
      await (
        await queries.getCheckCategoriesForPjNR(req.body.PjNr)
      ).hashImagesAndCreateIds(),
    (x) => {
      var ret = {};
      ret[`${identifiers.category}s`] = x;
      return ret;
    },
    res,
    next
  );

/**
 * similar to getCategories, but one level deeper
 */
const getCheckPoints = (req, res, next) =>
  errsafejson(
    async () =>
      await (
        await queries.getCheckPoints(req.body.PjNr, req.body.E1)
      ).hashImagesAndCreateIds(),
    (x) => {
      var ret = {};
      ret[`${identifiers.checkpoint}s`] = x;
      return ret;
    },
    res,
    next
  );

/**
 * similar to getCategories, but two levels deeper
 */
const getCheckPointDefects = (req, res, next) =>
  errsafejson(
    async () =>
      await (
        await queries.getCheckPointDefects(
          req.body.PjNr,
          req.body.E1,
          req.body.E2
        )
      ).hashImagesAndCreateIds(),
    (x) => {
      var ret = {};
      ret[`${identifiers.defect}s`] = x;
      return ret;
    },
    res,
    next
  );

/**
 * adds a new data entry (category/checkpoint/defect)
 */
const addNew = (req, res, next) =>
  errsafejson(
    async () => (await queries.addNew(req.body, req.user.KZL, req.user.Def_Login_ID))[0],
    (json) => { return { message: "added the entry", query_result: json } },
    res,
    next
  );

/**
 * updates a data entry
 */
const update = (req, res, next) =>
  errsafejson(
    async () => (await queries.update(req.body, req.user.Def_Login_ID))[0],
    (json) => ({ message: "updated the entry", query_result: json }),
    res,
    next
  );

/**
 * Updates MGAUFTR.Login_ID_Pruefer to the currently logged-in user, but only if it differs.
 * Intended to be called separately from other mutations.
 */
const touchPruefer = (req, res, next) =>
  errsafejson(
    async () => {
      const pjNr = req.body?.PjNr ?? req.body?.data?.PjNr;
      const out = await queries.touchPruefer(pjNr, req.user.Def_Login_ID);
      return out;
    },
    (json) => ({ message: "touched pruefer", ...json }),
    res,
    next
  );

/**
 * deletes a data entry
 */
const delete_ = (req, res, next) =>
  errsafejson(
    async () => (await queries.delete_(req.body, req.user.KZL)),
    (json) => ({ success: json.success, id: json.Index }),
    res,
    next
  );

const deleteImgByHash = (req, res, next) =>
  errsafejson(
    async () => {
      _logRequest("log", req, "delete-image-request", {
        hash: req.body?.hash,
      });
      const result = await queries.deleteImgByHash(
        req.body.hash,
        req.body?.data
      );
      _logRequest(
        result?.deleted ? "log" : "warn",
        req,
        "delete-image-result",
        {
          deleted: result?.deleted,
          reason: result?.reason,
          via: result?.resolvedVia,
          hash: req.body?.hash,
        }
      );
      return result;
    },
    (json) => { return { message: "deleted image", query_result: json } },
    res,
    next
  );

const setMainImgByHash = async (req, res, next) => {
  if(req.body.hash!=null){
    const pathparts = imghasher.getPathFromHash(req.body.hash);
    if(pathparts.link!=null && pathparts.filename!=null){
      const newLink = path.join(pathparts.link, pathparts.filename); // LinkOrdner+/+filename 
      // const newLink = path.join(pathparts.filename); // LinkOrdner+/+filename 
      req.body.data.Link = newLink;
    }else {
      _logRequest("warn", req, "set-main-image-invalid-hash", {
        hash: req.body.hash,
      });
    } 
  }else{
    _logRequest("warn", req, "set-main-image-missing-hash", {});
  }
  await update(req, res, next);
};

function guessImageContentType(filename) {
  const name = (filename ?? '').toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.bmp')) return 'image/bmp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  return 'application/octet-stream';
}

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash = async (req, res) => {
  try {
    const hash = req.body.hash;
    const pathparts = imghasher.getPathFromHash(hash) ?? {};
    const filename = pathparts.filename;

    let img = await imghasher.getFileFromHash(hash);
    res.writeHead(200, {
      "Content-type": guessImageContentType(filename),
      ...(filename ? { "x-image-filename": filename } : {}),
    });
    res.end(img);
  } catch (e) {
    res.status(404).json({ reason: "image no longer available" });
  }
};

const getDocFromPath = async (req, res) => {
  try {
    let docPath = imgfiler.formatpath(req.body.docPath);
    const filename = req.body?.filename;
    const stat = await fsp.stat(docPath);
    if (stat.isDirectory()) {
      if (filename == null || String(filename).trim().length === 0) {
        throw new Error("docPath points to directory without filename");
      }
      docPath = path.join(docPath, path.basename(String(filename)));
    }
    let img = await fsp.readFile(docPath);

    res.writeHead(200, { "Content-type": "application/octet-stream" });
    res.end(img);
  } catch (e) {
    _logRequest("warn", req, "doc-read-failed", {
      docPath: req.body?.docPath ?? null,
      reason: e?.message ?? String(e),
    });
    res.status(404).json({ reason: "doc no longer available" });
  }
};

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash_get = async (req, res) => {
  try {
    const hash = req.params.hash;
    const pathparts = imghasher.getPathFromHash(hash) ?? {};
    const filename = pathparts.filename;
    let img = await imghasher.getFileFromHash(hash);
    res.writeHead(200, {
      "Content-type": guessImageContentType(filename),
      ...(filename ? { "x-image-filename": filename } : {}),
    });
    res.end(img);
  } catch (e) {
    console.warn('failed to get image:',  e);
    res.status(404).json({ reason: "image no longer available" });
  }
};


const fileUpload = async (req, res) => {
  const filesCount = Array.isArray(req.files)
    ? req.files.length
    : req.file
      ? 1
      : 0;
  _uploadTrace(req, "start", {
    files: filesCount,
    pj: req?.body?.data?.PjNr,
    e1: req?.body?.data?.E1,
    e2: req?.body?.data?.E2,
    e3: req?.body?.data?.E3,
  });

  if (!(req.files || req.file)) {
    res.status(400).json({ success: false, reason: "no file uploaded" });
    _uploadWarn(req, "no-files", {});
    return;
  }

  // If this upload is the first image for the datapoint, set it as main image.
  // This has to happen here (after auth/login middleware) and not inside multer storage.
  try {
    const pendingHash = req.__pending_set_main_hash;
    const pendingLink = req.__pending_set_main_link;
    if (pendingHash && req.body && req.body.data) {
      // Ensure body data is an object.
      if (typeof req.body.data === "string") {
        try {
          req.body.data = JSON.parse(req.body.data);
        } catch (_) {}
      }
      const pathparts = imghasher.getPathFromHash(pendingHash);
      if (pendingLink) {
        req.body.hash = pendingHash;
        req.body.data.Link = pendingLink;
        const defLoginId =
          req.user?.Def_Login_ID ??
          req.user?.def_login_id ??
          req.user?.Login_ID_Pruefer ??
          req.user?.login_id_pruefer ??
          null;
        if (defLoginId != null) {
          await queries.update(req.body, defLoginId);
        } else {
          _uploadWarn(req, "main-image-update-skipped", { hash: pendingHash });
        }
      } else if (pathparts?.link != null && pathparts?.filename != null) {
        req.body.hash = pendingHash;
        req.body.data.Link = path.join(pathparts.link, pathparts.filename);
        const defLoginId =
          req.user?.Def_Login_ID ??
          req.user?.def_login_id ??
          req.user?.Login_ID_Pruefer ??
          req.user?.login_id_pruefer ??
          null;
        if (defLoginId != null) {
          await queries.update(req.body, defLoginId);
        } else {
          _uploadWarn(req, "main-image-update-skipped", { hash: pendingHash });
        }
      }
    }
  } catch (e) {
    _uploadWarn(req, "main-image-update-failed", {
      reason: e?.message ?? String(e)
    });
  }

  const uploaded = Array.isArray(req.__uploaded_images)
    ? req.__uploaded_images
    : [];

  try {
    for (const entry of uploaded) {
      const absPath = entry?.stored_absolute_path;
      const exists = absPath ? fs.existsSync(absPath) : false;
      let size = null;
      if (exists) {
        try {
          size = fs.statSync(absPath).size;
        } catch (_) {}
      }
      _uploadTrace(req, "saved", {
        file: entry?.stored_filename,
        hash: entry?.hash,
        bytes: size,
        exists,
        path: absPath,
      });
    }
  } catch (e) {
    _uploadWarn(req, "write-result-log-failed", {
      reason: e?.message ?? String(e),
    });
  }

  _uploadTrace(req, "done", {
    files: uploaded.length,
  });
  res.status(200).json({
    success: true,
    uploaded_images: uploaded,
  });
};

module.exports = {
  login,
  getLoginUsers,

  getProjects,
  getCategories,
  getCheckPoints,
  getCheckPointDefects,

  getDocFromPath,
  getFileFromHash,
  getFileFromHash_get,
  fileUpload,

  addNew,
  update,
  touchPruefer,
  delete_,

  deleteImgByHash,
  setMainImgByHash,
};
