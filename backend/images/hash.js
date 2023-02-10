const imgfiler = require("./filesystem");
const fs = require("fs");
const fsp = fs.promises;
const homedir = require('os').homedir()
const crypto = require('crypto');
const sharp = require('sharp')

// XXX: for #92 use https://www.npmjs.com/package/data-store
const NanoCache = require("nano-cache");
const options = require("../options");
var cache = new NanoCache({
  //ttl: 604800000, // store data in memory for exactly one week
  //limit: 5, // a hashed image may only be queried 5 times //maybe once would be better
  bytes: NanoCache.SIZE.GB, // cache memory usage must not exceed 1GB
});

// const storage = require('node-persist');

// const __hash_cache = storage.create({dir: '__hash_cache', ttl: 604800000*100});//store entries for 100 weeks
// __hash_cache.init();
// cache = {get:(e)=>__hash_cache.getItem(e), set:(e, b)=> __hash_cache.setItem(e,b)};

const getFileFromHash = async (hash, compressed) => {
  console.log("gettin file from ", await getPathFromHash(hash))
  let compressed_path = homedir + "/compressed_images/" + hash
  if (compressed && fs.existsSync(compressed_path + '/img.heic')) {
    let img = await fsp.readFile(compressed_path + '/img.heic')
    return img
  }

  let img = await imgfiler.getImageFrom(
    cache.get(hash + "r"),
    cache.get(hash + "l"),
    cache.get(hash + "f")
  );
  if (compressed) {
    const orig_img = img;
    img = await sharp(img)
      .heif({ quality: 1, effort: 0 })
      .toBuffer();

    sharp(orig_img)
      .heif({ quality: 1, effort: 9 })
      .toBuffer().then(async (buf) => {
        await fsp.mkdir(compressed_path, { recursive: true });
        fsp.writeFile(compressed_path + '/img.heic', img)
      })

  }
  return img
};

function throwExpression(errorMessage) {
  throw new Error(errorMessage);
}

const getPathFromHash = (hash) => {
  // console.log(hash);
  // console.log(cache.stats());
  const throwE = () => {
    throw new Error("-cache miss- , we couldnt resolve where that image is supposed to live");
  }
  return {
    rootpath: cache.get(hash + "r") ?? throwE(),
    link: cache.get(hash + "l") ?? throwE(),
    filename: cache.get(hash + "f") ?? throwE()
  }
};

const memorize = (rootpath, link, filename) => {
  // ja ein festes salt zu nehmen ist jetzt nicht so das Wahre, vorallem wenn es hier frei einlesbar ist, aber so wichtig ist dann auch nicht
  let key = (filename == options.no_image_placeholder_name) ? options.no_image_placeholder_name : crypto.createHash('sha1').update(rootpath + link + filename + 'v1').digest('base64');

  cache.set(key + "r", rootpath);
  cache.set(key + "l", link);
  cache.set(key + "f", filename);

  return key;
};

const memorize_link = (link) => memorize(link.rootfolder, link.link, link.filename);

module.exports = {
  getFileFromHash,
  getPathFromHash,
  memorize,
  memorize_link,
};
