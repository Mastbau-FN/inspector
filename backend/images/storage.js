const rootfolder = require("../db/queries").getLink;

const multer = require("multer");
const mstorage = multer.diskStorage({
  destination: (req, file, cb) => {
    rootfolder(req.body.PjNr).then((rf) => {
      cb(null, _formatpath(pathm.join(rf.rootfolder, rf.link)));
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
    mstorage,
};