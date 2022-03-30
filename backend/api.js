const queries = require("./db/queries");
const location = require("./extern/location");

const imghasher = require("./images/hash");
const path = require("path");

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
  let val;
  try {
    val = await statement();
  } catch (error) {
    return next({error: {errsafejson_captured: error}});
  }
  return res.status(200).json(await jsonmaker(val));
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
    async () =>
      await location.addCoords(
        await (await queries.getInspectionsForUser(req.user)).hashImagesAndCreateIds()
      ),
    (x) => {
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
    async () => (await queries.addNew(req.body, req.user.KZL))[0],
    (json) => {return{message: "added the entry", query_result: json}},
    res,
    next
  );

/**
 * updates a data entry
 */
const update = (req, res, next) =>
  errsafejson(
    async () => (await queries.update(req.body))[0],
    (json) => {return {message: "updated the entry", query_result: json}},
    res,
    next
  );

/**
 * updates a data entry
 */
const delete_ = (req, res, next) =>
  errsafejson(
    async () => (await queries.delete_(req.body, req.user.KZL))[0],
    (json) => ({ success: json.success, id: json.Index }),
    res,
    next
  );

const deleteImgByHash = (req, res, next) =>
  errsafejson(
    async () => (await queries.deleteImgByHash(req.body.hash))[0],
    (json) => {return{message: "deleted image", query_result: json}},
    res,
    next
  );

const setMainImgByHash = (req, res, next) => {
  const pathparts = imghasher.getPathFromHash(req.body.hash);
  const newLink = path.join(pathparts.link, pathparts.filename); // LinkOrdner+/+filename 
  // const newLink = path.join(pathparts.filename); // LinkOrdner+/+filename 
  console.log(req.body.hash,newLink);
  req.body.data.Link = newLink;
  return update(req, res, next);
};

/**
 * retrieves the file given by a hash and returns it to the client
 */
const getFileFromHash = async (req, res) => {
  try {
    let img = await imghasher.getFileFromHash(req.body.imghash);
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    res.status(404).json({ reason: "image no longer available" });
  }
};

const fileUpload = async (req, res) => {
  console.log("uploaded files");
  if (!(req.files || req.file)) {
    res.status(400).json({ reason: "no file uploaded" });
  } else {
    res.status(204).json();
  }
};

module.exports = {
  login,

  getProjects,
  getCategories,
  getCheckPoints,
  getCheckPointDefects,

  getFileFromHash,
  fileUpload,

  addNew,
  update,
  delete_,

  deleteImgByHash,
  setMainImgByHash,
};
