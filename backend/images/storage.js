const files = require("./filesystem")
const rootfolder = require("../db/queries").getLink;

const multer = require("multer");
const mstorage = multer.diskStorage({

  //done?: we currently store everything n the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
    rootfolder(req.body.thingy).then((rf) => {
      cb(null, files.formatpath(pathm.join(rf.rootfolder, rf.link)));
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
    mstorage,
};