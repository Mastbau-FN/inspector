const imgfiler = require("./filesystem");
const crypto = require('crypto');

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

const getFileFromHash = async (hash) => {
  if (typeof hash !== "string" || !hash.trim()) {
    throw Object.assign(new Error("An image hash is required"), { code: "INVALID_HASH" });
  }
  const { rootpath, link, filename } = getPathFromHash(hash);
  if (rootpath == null || link == null || filename == null) {
    throw Object.assign(new Error("Image hash is no longer available"), { code: "ENOENT" });
  }
  return imgfiler.getImageFrom(rootpath, link, filename);
};

function throwExpression(errorMessage) {
  throw new Error(errorMessage);
}

const getPathFromHash = (hash) => {
  if (typeof hash !== "string" || !hash.trim()) return {};
  return {
    rootpath: cache.get(hash + "r"),
    link: cache.get(hash + "l"),
    filename: cache.get(hash + "f"),
  };
};

const memorize = (rootpath, link, filename) => {
  // ja ein festes salt zu nehmen ist jetzt nicht so das Wahre, vorallem wenn es hier frei einlesbar ist, aber so wichtig ist dann auch nicht
  let key = ((filename == options.no_image_placeholder_name) ? options.no_image_placeholder_name : crypto.createHash('sha1').update(rootpath + link + filename + 'v1').digest('base64')).replace(/\//g, '_');

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
