const pathm = require("path");

const files = require("./filesystem")
const rootfolder = require("../db/queries").getLink;

const fs = require("fs");
const multer = require("multer");
const mstorage = multer.diskStorage({

  //done?: we currently store everything in the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
    rootfolder(req.body).then((rf) => {
      console.log("multi-upload",rf);
      const path = files.formatpath(pathm.join(rf.rootfolder, rf.link));
      fs.mkdirSync(path, { recursive: true });
      cb(null, path);
    });
  },
  filename: (req, file, cb) => {
    //TODO: if destination (extract above) is empty -> set the new image as main (aka as req.body.Link; update)
    cb(null, file.originalname);
  },
});

module.exports = {
    mstorage,
};