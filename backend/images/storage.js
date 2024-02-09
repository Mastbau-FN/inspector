const pathm = require("path");

const files = require("./filesystem");
const rootfolder = require("../db/queries").getLink;

const { memorize_link } = require("./hash");
const { setMainImgByHash } = require("../api");

const fs = require("fs");
const multer = require("multer");
const {
  set_first_image_as_main,
  no_image_placeholder_name,
} = require("../options");
const LOCALLY_ADDED_PREFIX = '__locally_added__';

const {ftb_ftb_id, update_hash_map } = require("../misc/frontend_wrapper_middleware");

const mstorage = multer.diskStorage({
  //done?: we currently store everything in the root dir, but we want to add into specific subdir that needs to be extracted from req.body.thingy.E1 etc
  destination: (req, file, cb) => {
	let frontendname = file.originalname;
	if(!file.originalname.startsWith(LOCALLY_ADDED_PREFIX)){
		file.originalname = file.fieldname+file.originalname;
		file.fieldname = frontendname;
	}else{
		file.originalname = LOCALLY_ADDED_PREFIX+file.fieldname+file.originalname;
		file.fieldname = frontendname;
	}
	
    console.info("file uploaded");
    //shouldnt be neccessary, since upload route used fieldparser as middleware
    try {
      //might fail if the body was already parsed
      req.body.data = JSON.parse(req.body.data);
    } catch (_) {}
    
    ftb_ftb_id(req).then((req) => {
      // console.log("🚀 ~ file: storage.js:30 ~ ftb_ftb_id ~ req", req.body);
    return rootfolder(req.body.data).then((rf) => {
      	// console.log("🚀 ~ file: storage.js:29 ~ rootfolder ~ rf", rf)
      	console.log("multi-upload", rf);
      	const path = files.formatpath(pathm.join(rf.rootfolder, rf.link));
      	fs.mkdirSync(path, { recursive: true });
      	let prev_filename = rf.filename;
      	fs.readdir(path, {}, (err, files) => {
        	rf.filename = file.originalname;
        	//lil race condition workaround: if file already added length is increased by 1
	
        	// if (files.length < 1 + files.includes(prev_filename)) {
	
        	let hash = memorize_link(rf);
	
        	if (rf.filename.startsWith(LOCALLY_ADDED_PREFIX)) {
          	update_hash_map({hash: rf.filename}, hash);
        	}
	
	
        	//: if destination is empty -> set the new image as main (aka as req.body.Link; update)
        	if (
          	set_first_image_as_main &&
          	!prev_filename || prev_filename == no_image_placeholder_name
        	) {
          	req.body.hash = hash;
          	setMainImgByHash(req, { status: (_) => {return {json:(_)=>{}}} }, (err, res) => { });
        	}
        	// }
	
	
      	});
      	cb(null, path);
	
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
