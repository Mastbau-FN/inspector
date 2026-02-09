const pathm = require("path");

const files = require("./filesystem");
const rootfolder = require("../db/queries").getLink;

const { memorize_link } = require("./hash");

const fs = require("fs");
const multer = require("multer");
const {
  set_first_image_as_main,
  no_image_placeholder_name,
} = require("../options");
const LOCALLY_ADDED_PREFIX = '__locally_added__';
const SHORT_LOCALLY_ADDED_PREFIX = '__loc__';

const { decorateDataFromLocalId } = require("../misc/local_id");

const mstorage = multer.diskStorage({
  //done?: we currently store everything in the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
    let frontendname = file.originalname;
    const date = new Date(Number(file.fieldname));
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0'); // Months are 0-based in JS
    const year = date.getFullYear();
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');

    // Format the date as "dd_MM_yyyy_HH_mm_ss"
    const formattedDate = `${day}_${month}_${year}_${hours}_${minutes}_${seconds}`;
    file.fieldname = formattedDate;
    if(!file.originalname.startsWith(LOCALLY_ADDED_PREFIX) && !file.originalname.startsWith(SHORT_LOCALLY_ADDED_PREFIX)){
        file.originalname = file.fieldname+".jpg";
        file.fieldname = frontendname;
    }else{
        file.originalname = SHORT_LOCALLY_ADDED_PREFIX+file.fieldname+(Math.random() + 1).toString(36).substring(8)+".jpg";
        file.fieldname = frontendname;
    }
    
    console.info("file uploaded");
    //shouldnt be neccessary, since upload route used fieldparser as middleware
    try {
      //might fail if the body was already parsed
      req.body.data = JSON.parse(req.body.data);
    } catch (_) {}

    try {
      req.body.data = decorateDataFromLocalId(req.body.data);
    } catch (_) {}

    return rootfolder(req.body.data).then((rf) => {
        // console.log("🚀 ~ file: storage.js:29 ~ rootfolder ~ rf", rf)
        
        console.log("multi-upload", rf);
        const path = files.formatpath(pathm.join(rf.rootfolder, rf.link));
        fs.mkdirSync(path, { recursive: true });
        let prev_filename = rf.filename;

        // compute the hash for the stored filename immediately
        const rfForHash = { ...rf, filename: file.originalname };
        const hash = memorize_link(rfForHash);
        rf.filename = file.originalname;

        if (!req.__uploaded_images) req.__uploaded_images = [];
        req.__uploaded_images.push({
          client_filename: frontendname,
          stored_filename: file.originalname,
          hash,
        });

        // If destination was empty -> set the new image as main (aka as req.body.Link; update).
        // Defer this until after multer finished and auth/login wall ran, otherwise req.user is not available yet.
        if (
          set_first_image_as_main &&
          (!prev_filename || prev_filename == no_image_placeholder_name) &&
          !req.__pending_set_main_hash
        ) {
          req.__pending_set_main_hash = hash;
        }
        cb(null, path);
    
    });
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});

module.exports = {
  mstorage,
};
