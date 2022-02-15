const imgfiler = require("./filesystem");

const bcript = require("bcrypt");

// XXX: for #92 use https://www.npmjs.com/package/data-store
const NanoCache = require("nano-cache");
var cache = new NanoCache({
  //ttl: 604800000, // store data in memory for exactly one week
  //limit: 5, // a hashed image may only be queried 5 times //maybe once would be better
  bytes: NanoCache.SIZE.GB, // cache memory usage must not exceed 1GB
});

const getFileFromHash = async (hash) => {
  return await imgfiler.getImageFrom(
    cache.get(hash + "r"),
    cache.get(hash + "l"),
    cache.get(hash + "f")
  );
};

function throwExpression(errorMessage){
  throw new Error(errorMessage);
}

const getPathFromHash = (hash) => {
  // console.log(hash);
  // console.log(cache.stats());
  const  throwE = ()=>{
    throw new Error("-cache miss- , we couldnt resolve where that image is supposed to live");
  }
  return {
    rootpath: cache.get(hash + "r") ?? throwE(),
    link:     cache.get(hash + "l") ?? throwE(),
    filename: cache.get(hash + "f") ?? throwE()
  }
};

const memorize = async (rootpath, link, filename) => {
  // ja ein festes salt zu nehmen ist jetzt nicht so das Wahre, vorallem wenn es hier frei einlesbar ist, aber so wichtig ist dann auch nicht
  let key = await bcript.hash(rootpath + link + filename, '$2b$10$DNz2TF9EXMD2EENXEEE9t.');

  //okay this is honestly kinda shitty, but probably faster than serializing and deserializing
  cache.set(key + "r", rootpath);
  cache.set(key + "l", link);
  cache.set(key + "f", filename);

  return key;
};

module.exports = {
  getFileFromHash,
  getPathFromHash,
  memorize,
};
