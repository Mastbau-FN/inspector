const fs = require('fs');
const fsp = fs.promises;

const pathm = require('path');


const root_path = process.env.IMG_ROOT_PATH; //might be needed when mounting network drives locally

///removes the drive and replaces it with our given root path
const _formatpath = (path) => {
    const parts = path.split(pathm.sep);
    const drive = parts.shift()[0];
    path = pathm.join(root_path, drive ,...parts);
    return path;
};


const getImageFrom = (rootpath,link,filename) => fsp.readFile(_formatpath(pathm.join(rootpath,link,filename)));


const _getAllImagenamesFromPath = async (path) => {
    path = _formatpath(path);

    const dirents = await fsp.readdir(path, { withFileTypes: true });
    return dirents
        .filter(dirent => dirent.isFile())
        .map(dirent => dirent.name);
}

const getAllImagenamesFrom = async (rootpath, link) => {
    try {return await _getAllImagenamesFromPath(pathm.join(rootpath,link))}catch(e){console.warn("failed to get image names: ",e);return []}
}




const rootfolder = require('../db/queries').getLink;
const multer = require('multer');
const mstorage = multer.diskStorage({
    destination:(req,file,cb)=>{
        rootfolder(req.body.PjNr).then(rf => {
            cb(null,_formatpath(pathm.join(rf.rootfolder, rf.link)));
        })
    },
    filename:(req,file,cb)=>{
        cb(null,file.originalname);
    },
});




module.exports = {
    getAllImagenamesFrom,
    getImageFrom,
    mstorage
}