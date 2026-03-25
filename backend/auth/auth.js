require("dotenv").config();
const db = require("../db/queries");

const api_wall = (req, res, next) => {
  if (!req.headers.authorization) {
    return res.status(401).json({ error: "No auth header given" });
  }
  if (!(req.headers.authorization == process.env.API_KEY)) {
    console.log(
      "[auth] api-key-rejected",
      JSON.stringify({
        request_id: req.__request_id ?? null,
        method: req.method,
        path: req.originalUrl ?? req.url,
        has_authorization: true,
      })
    );
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
    console.log(
      "[auth] login-rejected",
      JSON.stringify({
        request_id: req.__request_id ?? null,
        method: req.method,
        path: req.originalUrl ?? req.url,
        user: req.body?.user?.name ?? req.body?.user?.KZL ?? null,
        reason: e?.message ?? String(e),
      })
    );
    return res.status(403).json({ error: "wrong credentials" });
  }
};

module.exports = {
  api_wall,
  login_wall,
};
