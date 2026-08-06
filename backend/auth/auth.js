require("dotenv").config();
const db = require("../db/queries");
const logger = require("../misc/logger");

const api_wall = (req, res, next) => {
  if (!req.headers.authorization) {
    logger.logEvent("warn", "auth", "api-key-missing", req);
    return res.status(401).json({ error: "No auth header given" });
  }
  if (!(req.headers.authorization == process.env.API_KEY)) {
    logger.logEvent("warn", "auth", "api-key-rejected", req);
    return res.status(403).json({ error: "NOT AUTHORIZED" });
  }
  return next();
};

const login_wall = async (req, res, next) => {
  // Allow image GETs (used by web/NetworkImage) without a login payload.
  if (/^\/get\//.test(req.path)) return next();

  try {
    let user = await db.getValidUser(req.body.user);
    //important s.t. we can use req.user in all api-calls that require a user to be logged in
    req.user = user;
    return next();
  } catch (e) {
    logger.logEvent("warn", "auth", "login-rejected", req, {
      ...logger.errorContext(e),
    });
    return res.status(403).json({ error: "wrong credentials" });
  }
};

module.exports = {
  api_wall,
  login_wall,
};
