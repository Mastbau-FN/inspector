require("dotenv").config();

const Pool = require("pg").Pool;
const logger = require("../misc/logger");

const DEFAULT_SLOW_QUERY_MS = 5_000;

function _positiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function _sqlSummary(querystring) {
  return String(querystring ?? "")
    .replace(/--.*$/gm, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 500);
}

let db = [];

db.pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.POSTGRES_HOST,
  database: process.env.POSTGRES_DATABASE,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.POSTGRES_PORT,
});
db.pool.asyncQuery = (querystring, args) => {
  const startedAt = Date.now();
  const sql = _sqlSummary(querystring);
  const queryParams = Array.isArray(args) ? args.length : 0;
  const slowQueryMs = _positiveInt(
    process.env.BACKEND_SLOW_QUERY_MS,
    DEFAULT_SLOW_QUERY_MS
  );
  let finished = false;

  const slowTimer = setTimeout(() => {
    if (!finished) {
      logger.logEvent("warn", "database", "slow-query", null, {
        durationMs: Date.now() - startedAt,
        queryParams,
        sql,
      });
    }
  }, slowQueryMs);
  slowTimer.unref?.();

  return new Promise((resolve, reject) => {
    db.pool.query(querystring, args, (err, data) => {
      finished = true;
      clearTimeout(slowTimer);
      const durationMs = Date.now() - startedAt;

      if (err) {
        err.backendSql = sql;
        err.backendParameterCount = queryParams;
        err.backendQueryDurationMs = durationMs;
        logger.logEvent("error", "database", "query-failed", null, {
          durationMs,
          queryParams,
          sql,
          ...logger.errorContext(err),
        });
        reject(err);
        return;
      }
      resolve(data);
    });
  });
};

module.exports = {
  db,
};
