const fs = require('fs');
const fsp = fs.promises;

const root_path = process.env.img_root_path;

const _getImageFromPath = async (path) => {
    //TODO get image from network (siehe [#9](https://github.com/Mastbau-FN/inspector/issues/9))
    return await fsp.readFile(path);
}

const getImageFrom = async (rootpath,link,filename)=>{
    //TODO how to merge the specific paths and where do they come from?
    return await _getImageFromPath(rootpath+link+filename);
}


const _getAllImagenamesFromPath = async (path) => {
    //TODO get image from network (siehe [#9])
    return await fsp.readdir(path);
}

const getAllImagenamesFrom = async (rootpath, link) => {
    //TODO how to merge the specific paths and where do they come from?
    return await _getAllImagenamesFromPath(rootpath+link)
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