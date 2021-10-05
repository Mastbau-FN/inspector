const fs = require('fs');
const fsp = fs.promises;

const pathm = require('path');


const root_path = process.env.IMG_ROOT_PATH; //might be needed when mounting network drives locally

///removes the drive and replaces it with our given root path
const _formatpath = (path) => {
    const parts = path.split(pathm.sep);
    parts.shift();
    pathm.join(root_path,...parts);
};


const _getImageFromPath = async (path) => {
    ////console.log(path)
    //TODO get image from network (siehe [#9](https://github.com/Mastbau-FN/inspector/issues/9))
    return await fsp.readFile(path);
}

const getImageFrom = async (rootpath,link,filename)=>{
    //TODO how to merge the specific paths and where do they come from?
    return await _getImageFromPath(pathm.join(_formatpath(rootpath),link,filename));
}


const _getAllImagenamesFromPath = async (path) => {
    //TODO get image from network (siehe [#9])
    const dirents = await fsp.readdir(path, { withFileTypes: true });
    return dirents
        .filter(dirent => dirent.isFile())
        .map(dirent => dirent.name);
}

const getAllImagenamesFrom = async (rootpath, link) => {
    //TODO how to merge the specific paths and where do they come from?
    ////console.log(rootpath);console.log(link);
    try {return await _getAllImagenamesFromPath(pathm.join(_formatpath(rootpath),link))}catch(e){return []}
}

module.exports = {
    getAllImagenamesFrom,
    getImageFrom
}

// MARK: deprecated

// const _getAllFilesInPath = async (path) => {
//     //TODO get image from network (siehe #9)
//     const filenames = await fsp.readdir(path);

//     const results = [];
//     filenames.forEach((filename) => {
//         results.push(_getImageFromPath(path+filename));
//     });
//     return await Promise.all(results);
// }
// const getAllImagesFrom = async (rootpath, link) => {
//     //TODO how to merge the specific paths and where do they come from?
//     return await _getAllFilesInPath(rootpath+link)
// }