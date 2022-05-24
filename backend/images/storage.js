const pathm = require("path");

const files = require("./filesystem");
const rootfolder = require("../db/queries").getLink;

const { memorize_link } = require("./hash");
const { setMainImgByHash } = require("../api");

const fs = require("fs");
const multer = require("multer");
const { set_first_image_as_main, no_image_placeholder_name } = require("../options");

const mstorage = multer.diskStorage({
  //done?: we currently store everything in the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
    rootfolder(req.body).then((rf) => {
      console.log("multi-upload", rf);
      const path = files.formatpath(pathm.join(rf.rootfolder, rf.link));
      fs.mkdirSync(path, { recursive: true });
      cb(null, path);
      //: if destination is empty -> set the new image as main (aka as req.body.Link; update)
      if (set_first_image_as_main && rf.mainImg == no_image_placeholder_name)
        fs.readdir(path, {}, (err, files) => {
          if (files.length < 3) {
            rf.filename = file.originalname;
            req.body.hash = memorize_link(rf);
            setMainImgByHash(req, {}, (err, res) => {});
          }
        });
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
  mstorage,
};
