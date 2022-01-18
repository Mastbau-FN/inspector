const imgfiler = require("./filesystem");

const bcript = require("bcrypt");

// XXX: for #92 use https://www.npmjs.com/package/data-store
const NanoCache = require("nano-cache");
var cache = new NanoCache({
  ttl: 604800000, // store data in memory for exactly one week
  limit: 5, // a hashed image may only be queried 5 times //maybe once would be better
  bytes: NanoCache.SIZE.GB, // cache memory usage must not exceed 1GB
});

const getFileFromHash = async (hash) => {
  return await imgfiler.getImageFrom(
    cache.get(hash + "r"),
    cache.get(hash + "l"),
    cache.get(hash + "f")
  );
};

const getPathFromHash = (hash) => {
  console.log(hash);
  console.log(cache.stats());
  return {
    rootpath: cache.get(hash + "r"),
    link:     cache.get(hash + "l"),
    filename: cache.get(hash + "f")
  }
};

const memorize = async (rootpath, link, filename) => {
  let key = await bcript.hash(rootpath + link + filename, 1);
  //console.log(key);

  ////console.log({rootpath,link,filename});

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
