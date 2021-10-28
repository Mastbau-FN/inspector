const queries = require("./db/queries");
const imagehandler = require("./images/hash");

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
      await (
        await queries.getInspectionsForUser(req.user)
      ).hashImages(),
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
      (await queries.addNew(req.body))[0],
    (json)=> (json),
    res,next
  );

const getFileFromHash = async (req, res) => {
  try {
    let img = await imagehandler.getFileFromHash(req.body.imghash);
    res.writeHead(200, { "Content-type": "image/jpg" });
    res.end(img);
  } catch (e) {
    res.status(404).json({ reason: "image no longer available" });
  }
};

const fileUpload = async (req, res) => {
  if (!req.file) {
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
};
