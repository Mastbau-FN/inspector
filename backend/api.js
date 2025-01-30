const queries = require("./db/queries");
const location = require("./extern/location");
const docfiler = require("./images/filesystem");
const imghasher = require("./images/hash");
const path = require("path");
const options = require("./options");
const memorize_link = require("./images/hash").memorize_link;

const identifiers = require("./misc/identifiers").identifiers;

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
    // console.log(res)
    if (!res.headersSent) return res.status(200).json(jsonderulo);
  } catch (error) {
    console.warn(error, "caler");
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
  json_response.user = req.user;
  res.status(200).json(json_response);
};

/**
 * resolves all projects / inspections / locations for the currently logged-in user
 */
const getProjects = (req, res, next) =>
  errsafejson(
    // Teil 1: async Callback, der die Daten (Projekte/Dokus) ermittelt
    async () => {
      // 1) Projekte/Inspektionen aus DB
      let inspections = await queries.getInspectionsForUser(req.user);
      // 2) Bilder hashen
      inspections.hashImagesAndCreateIds();

      // 3) Dokus-Ordner einlesen
      for (let insp of inspections) {
        // Hier musst du an die Infos kommen, wo dein Inspektionsordner liegt.
        // Viele Implementierungen haben so etwas wie insp.rootfolder, insp.link, insp.filename
        // Falls das bei dir abweicht, passe die Variablennamen entsprechend an.
        const rootfolder = insp.rootfolder || "";
        const link = insp.LinkOrdner || "";

        // Pfad zum Dokus-Ordner
        const dokusSubDir = path.join(link, "Dokus");
        // Dateien aus /Dokus lesen
        const fileNames = await docfiler.getAllFilenamesFrom(rootfolder, dokusSubDir);
        // => z.B. [ "Handbuch.pdf", "Plan.docx", ...]
        const dokusHashed = fileNames.map((fileName) =>
          memorize_link({
            rootfolder,
            link: dokusSubDir,
            filename: fileName,
          })
        );
        
        // An die Inspektion hängen (statt einer Liste von Maps, jetzt nur eine Liste von Strings)
        insp.Dokus = dokusHashed;
      }

      // 4) Optional Koordinaten-Auflösung (useReverseLocationAPI)
      if (options.useReverseLocationAPI) {
        inspections = await location.addCoords(inspections);
      }

      // Rückgabe
      return inspections;
    },

    // Teil 2: Ergebnis in die gewünschte JSON-Struktur packen
    (inspections) => {
      const ret = {};
      // Bsp.: ret["locations"] = inspections  (oder "projects" o.ä.)
      ret[`${identifiers.location}s`] = inspections;
      return ret;
    },

    // Teil 3: Übergabe der üblichen Express-Objekte an errsafejson
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
    async () => (await queries.addNew(req.body, req.user.KZL))[0],
    (json) => {
      return { message: "added the entry", query_result: json };
    },
    res,
    next
  );

/**
 * updates a data entry
 */
const update = (req, res, next) =>
  errsafejson(
    async () => (await queries.update(req.body))[0],
    (json) => ({ message: "updated the entry", query_result: json }),
    res,
    next
  );

/**
 * deletes a data entry
 */
const delete_ = (req, res, next) =>
  errsafejson(
    async () => await queries.delete_(req.body, req.user.KZL),
    (json) => ({ success: json.success, id: json.Index }),
    res,
    next
  );

const deleteImgByHash = (req, res, next) =>
  errsafejson(
    async () => await queries.deleteImgByHash(req.body.hash),
    (json) => {
      return { message: "deleted image", query_result: json };
    },
    res,
    next
  );

const setMainImgByHash = async (req, res, next) => {
  // console.log("🚀 ~ file: api.js:163 ~ setMain ~ resreq", {req}, {res})

  if (req.body.hash != null) {
    const pathparts = imghasher.getPathFromHash(req.body.hash);
    if (pathparts.link != null && pathparts.filename != null) {
      const newLink = path.join(pathparts.link, pathparts.filename); // LinkOrdner+/+filename
      // const newLink = path.join(pathparts.filename); // LinkOrdner+/+filename
      req.body.data.Link = newLink;
    } else {
      console.log("hash ungültig oder null");
    }
  } else {
    console.log("kein hash übergeben");
  }

  // console.log("setmainimagehash api backend", req.body.hash, newLink);
  // res.status(200).json({ reason: 'kein 404 bitte'}) //FIX-ME: aus irgendeinem grund wird in update oder so 404er header geworfen und die app denkt es ist fehlgeschlagen obwohl eigtl alles geht, uns ist aber unklar wieso, aber so klappts als dirty fix erstmal, die logs sind bloß etwas kagge
  await update(req, res, next);
};
const getDokuFile = async (req, res) => {


    // etc...
    try {
      const hash  = req.body.hash;
      // MIME-Type bestimmen (rudimentär, optional)
      let contentType = "application/octet-stream";
      let doc = await imghasher.getFileFromHash(
        hash,
        false,
      );
      res.writeHead(200, { "Content-type": contentType  });
      res.end(doc);
    } catch (e) {
      res.status(404).json({ reason: "doc no longer available" });
    }
    // Für Download:
    // res.setHeader('Content-Disposition', `attachment; filename="${info.filename}"`);

  }


// Route registrieren (z. B. in router.js)

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash = async (req, res) => {
  try {
    let img = await imghasher.getFileFromHash(
      req.body.hash,
      req.body.compressed
    );
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    res.status(404).json({ reason: "image no longer available" });
  }
};

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash_get = async (req, res) => {
  try {
    let img /*;
    try {
      img*/ = await imghasher.getFileFromHash(req.params.hash, true); //serve compressed images only
    // } catch (e) {
    //   img = await imghasher.getFileFromHash(req.params.hash, false); //fallback to non-compressed
    // }
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    console.warn("failed to get image:", e);
    res.status(404).json({ reason: "image no longer available" });
  }
};

const fileUpload = async (req, res) => {
  console.log("uploading files..");
  if (!(req.files || req.file)) {
    res.status(204).json({ reason: "no file uploaded" });
    console.log("file failed");
  } else {
    res.status(204).json();
    console.log("file succeeded");
  }
};

module.exports = {
  login,

  getProjects,
  getCategories,
  getCheckPoints,
  getCheckPointDefects,

  getFileFromHash,
  getFileFromHash_get,
  fileUpload,

  addNew,
  update,
  delete_,

  deleteImgByHash,
  setMainImgByHash,

  getDokuFile,
};
