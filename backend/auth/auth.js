require("dotenv").config();
const db = require("../db/queries");

const api_wall = (req, res, next) => {
  if (!req.headers.authorization) {
    return res.status(401).json({ error: "No auth header given" });
  }
  if (!(req.headers.authorization == process.env.API_KEY_OLD || req.headers.authorization == process.env.API_KEY)) { //TODO: remove old key
    console.log("tried auth", req.headers.authorization);
    return res.status(403).json({ error: "NOT AUTHORIZED" });
  }
  return next();
};

const login_wall = async (req, res, next) => {
  const loginFreePaths = [/get\/compressed/];
  //if any regex in loginFreePath matches, skip
  // console.log(req.path, /get\/compressed/.test(req.path))
  if (loginFreePaths.some(regex => regex.test(req.path))) return next();

  try {
    let user = await db.getValidUser(req.body.user);
    //important s.t. we can use req.user in all api-calls that require a user to be logged in
    req.user = user;
    return next();
  } catch (e) {
    console.log(`someone tried access with`, req.body, e);
    return res.status(403).json({ error: "wrong credentials" });
  }
};

module.exports = {
  api_wall,
  login_wall,
};

