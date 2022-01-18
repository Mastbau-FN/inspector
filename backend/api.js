const queries = require("./db/queries");
const location = require("./extern/location");

const imghasher = require("./images/hash");
const path = require("path");

//errorhandling

const errsafejson = async (statement, jsonmaker, res, next) => {
  let val;
  try {
    val = await statement();
  } catch (error) {
    return next(error);
  }
  return res.status(200).json(await jsonmaker(val));
};

//TODO: docstrings

const login = (req, res) => {
  let json_response = { success: true };
  json_response.user = req.user;
  res.status(200).json(json_response);
};

const getProjects = (req, res, next) => errsafejson(
    async () =>
      await location.addCoords(await (
        await queries.getInspectionsForUser(req.user)
      ).hashImages()),
    (x)=>({inspections: x}),
    res,next
  );

const getCategories = (req, res, next) => errsafejson(
    async () =>
      await (
        await queries.getCheckCategoriesForPjNR(req.body.PjNr)
      ).hashImages(),
    (x)=>({categories: x}),
    res,next
  );

const getCheckPoints = (req, res, next) => errsafejson(
    async () =>
      await (
        await queries.getCheckPoints(req.body.PjNr, req.body.E1)
      ).hashImages(),
    (x)=>({checkpoints: x}),
    res,next
  );

const getCheckPointDefects = (req, res, next) => errsafejson(
    async () =>
      await (
        await queries.getCheckPointDefects(
          req.body.PjNr,
          req.body.E1,
          req.body.E2
        )
      ).hashImages(),
    (x)=>({checkpointdefects:x}),
    res,next
  );

const addNew = (req, res, next) =>
  errsafejson(
    async () =>
      (await queries.addNew(req.body,req.user.KZL))[0],
    (json)=> (json),
    res,next
  );

const update = (req, res, next) =>
  errsafejson(
    async () =>
      (await queries.update(req.body))[0],
    (json)=> (json),
    res,next
  );

const delete_ = (req, res, next) =>
  errsafejson(
    async () =>
      (await queries.delete_(req.body, req.user.KZL))[0],
    (json)=> ({success:json.success, id: json.Index}),
    res,next
  );

const deleteImgByHash = (req, res, next) =>
  errsafejson(
    async () =>
      (await queries.deleteImgByHash(req.body.hash))[0],
    (json)=> (json),
    res,next
  );

  const setMainImgByHash = (req, res, next) => {
    const pathparts = imghasher.getPathFromHash(req.body.hash);
    req.body.data.Link = path.join(pathparts.Link,pathparts.filename); // LinkOrdner+/+filename
    return update(req,res,next);
  }

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
  console.log("uploaded files")
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
