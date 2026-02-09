const queries = require("./db/queries");
const location = require("./extern/location");

const imghasher = require("./images/hash");
const path = require("path");
const options = require("./options");

const fs = require("fs");
const fsp = fs.promises;
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
    console.warn(error, "caler")
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
  console.log(
    "user logged in:",
    req.user?.KZL,
    "Def_Login_ID:",
    defLoginId,
    "keys:",
    Object.keys(req.user ?? {})
  );
  res.status(200).json(json_response);
};

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
      if (out?.updated) {
        console.log(
          `touchPruefer: PjNr=${pjNr} old=${out.old_login_id_pruefer} new=${out.login_id_pruefer} (KZL=${req.user?.KZL}, Def_Login_ID=${req.user?.Def_Login_ID})`
        );
      }
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
    async () => (await queries.deleteImgByHash(req.body.hash)),
    (json) => { return { message: "deleted image", query_result: json } },
    res,
    next
  );

const setMainImgByHash = async (req, res, next) => {
  // console.log("🚀 ~ file: api.js:163 ~ setMain ~ resreq", {req}, {res})

  if(req.body.hash!=null){
    const pathparts = imghasher.getPathFromHash(req.body.hash);
    if(pathparts.link!=null && pathparts.filename!=null){
      const newLink = path.join(pathparts.link, pathparts.filename); // LinkOrdner+/+filename 
      // const newLink = path.join(pathparts.filename); // LinkOrdner+/+filename 
      req.body.data.Link = newLink;
    }else {
      console.log("hash ungültig oder null")
    } 
  }else{
    console.log("kein hash übergeben")
  }


  // console.log("setmainimagehash api backend", req.body.hash, newLink);
  // res.status(200).json({ reason: 'kein 404 bitte'}) //FIX-ME: aus irgendeinem grund wird in update oder so 404er header geworfen und die app denkt es ist fehlgeschlagen obwohl eigtl alles geht, uns ist aber unklar wieso, aber so klappts als dirty fix erstmal, die logs sind bloß etwas kagge
  await update(req, res, next);
};

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash = async (req, res) => {
  try {
    let img = await imghasher.getFileFromHash(req.body.hash, req.body.compressed);
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    res.status(404).json({ reason: "image no longer available" });
  }
};

const getDocFromPath = async (req, res) => {
  try {
    console.log("docPath", req.body.docPath);
    let img = await fsp.readFile(req.body.docPath);

    res.writeHead(200, { "Content-type": "application/octet-stream" });
    res.end(img);
  } catch (e) {
    console.log("FHleer")
    res.status(404).json({ reason: "doc no longer available" });
  }
};

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash_get = async (req, res) => {
  try {
    let img/*;
    try {
      img*/ = await imghasher.getFileFromHash(req.params.hash, true); //serve compressed images only
    // } catch (e) {
    //   img = await imghasher.getFileFromHash(req.params.hash, false); //fallback to non-compressed
    // }
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    console.warn('failed to get image:',  e);
    res.status(404).json({ reason: "image no longer available" });
  }
};


const fileUpload = async (req, res) => {
  console.log("uploading files..");
  if (!(req.files || req.file)) {
    res.status(204).json({ reason: "no file uploaded" });
    console.log("file failed")
  } else {
    res.status(204).json();
    console.log("file succeeded")
  }
};

module.exports = {
  login,

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
