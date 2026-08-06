const { AsyncLocalStorage } = require("async_hooks");

const requestStorage = new AsyncLocalStorage();
const DEFAULT_SLOW_REQUEST_MS = 10_000;
const MAX_LOG_VALUE_LENGTH = 2_000;

let activeApiRequests = 0;

function _newRequestId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function _positiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function _path(req) {
  const raw = req?.originalUrl ?? req?.url ?? "-";
  return String(raw).split("?", 1)[0];
}

function _isApiRequest(req) {
  return _path(req).startsWith("/api/");
}

function _cleanValue(value) {
  if (value == null) return undefined;
  if (typeof value === "number" || typeof value === "boolean") return value;
  if (typeof value === "bigint") return value.toString();
  if (value instanceof Date) return value.toISOString();

  const normalized = String(value).replace(/\s+/g, " ").trim();
  if (normalized.length <= MAX_LOG_VALUE_LENGTH) return normalized;
  return `${normalized.slice(0, MAX_LOG_VALUE_LENGTH)}…`;
}

function _compact(fields = {}) {
  const compacted = {};
  for (const [key, value] of Object.entries(fields)) {
    const cleaned = _cleanValue(value);
    if (cleaned !== undefined && cleaned !== "") compacted[key] = cleaned;
  }
  return compacted;
}

function requestContext(req) {
  const body = req?.body && typeof req.body === "object" ? req.body : {};
  const data = body.data && typeof body.data === "object" ? body.data : body;
  const authenticatedUser = req?.user ?? {};
  const suppliedUser = body.user && typeof body.user === "object" ? body.user : {};
  const files = Array.isArray(req?.files) ? req.files.length : req?.file ? 1 : undefined;

  // Deliberately only log identifiers needed to find a failed sync item. Text,
  // passwords, API keys and the complete request payload never enter the log.
  return _compact({
    type: body.type,
    pjNr: data.PjNr ?? body.PjNr,
    e1: data.E1 ?? body.E1,
    e2: data.E2 ?? body.E2,
    e3: data.E3 ?? body.E3,
    localId: data.local_id,
    parentLocalId: data.parent_local_id,
    mainhash: data.mainhash,
    hash: body.hash,
    user: authenticatedUser.KZL ?? suppliedUser.name ?? suppliedUser.KZL,
    files,
    contentType: req?.headers?.["content-type"],
    contentLength: req?.headers?.["content-length"],
  });
}

function errorContext(error) {
  const source = error?.originalError ?? error?.cause ?? error ?? {};
  return _compact({
    errorName: source.name,
    errorMessage: source.message ?? String(source),
    errorCode: source.code,
    errorDetail: source.detail,
    errorHint: source.hint,
    errorWhere: source.where,
    errorSchema: source.schema,
    errorTable: source.table,
    errorColumn: source.column,
    errorConstraint: source.constraint,
    errorRoutine: source.routine,
    queryFile: source.backendQueryFile,
    queryParams: source.backendParameterCount,
    queryDurationMs: source.backendQueryDurationMs,
    sql: source.backendSql,
    stack: source.stack,
  });
}

function _storedRequest() {
  return requestStorage.getStore()?.req;
}

function logEvent(level, scope, event, req, fields = {}) {
  const activeReq = req ?? _storedRequest();
  const logger = typeof console[level] === "function" ? console[level] : console.log;
  const entry = {
    timestamp: new Date().toISOString(),
    scope,
    event,
    requestId:
      activeReq?.__request_id ?? requestStorage.getStore()?.requestId ?? "-",
    method: activeReq?.method,
    path: activeReq ? _path(activeReq) : undefined,
    ...requestContext(activeReq),
    ..._compact(fields),
  };

  logger(`[${scope}] ${JSON.stringify(_compact(entry))}`);
}

const logreq = (req, res, next) => {
  const requestId = _newRequestId();
  const isApiRequest = _isApiRequest(req);
  const startedAt = Date.now();
  let completed = false;

  req.__request_id = requestId;
  req.__request_started_at = startedAt;
  res.setHeader("X-Request-ID", requestId);

  if (isApiRequest) {
    activeApiRequests += 1;
    logEvent("log", "request", "started", req, { activeApiRequests });
  }

  const slowRequestMs = _positiveInt(
    process.env.BACKEND_SLOW_REQUEST_MS,
    DEFAULT_SLOW_REQUEST_MS
  );
  const slowTimer = isApiRequest
    ? setTimeout(() => {
        if (!completed) {
          logEvent("warn", "request", "slow", req, {
            durationMs: Date.now() - startedAt,
            status: res.statusCode,
            activeApiRequests,
          });
        }
      }, slowRequestMs)
    : null;
  slowTimer?.unref?.();

  const complete = (event) => {
    if (completed) return;
    completed = true;
    if (slowTimer) clearTimeout(slowTimer);
    if (!isApiRequest) return;

    activeApiRequests = Math.max(0, activeApiRequests - 1);
    const level = res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "log";
    logEvent(level, "request", event, req, {
      status: res.statusCode,
      durationMs: Date.now() - startedAt,
      activeApiRequests,
    });
  };

  req.on("aborted", () => complete("aborted"));
  res.on("finish", () => complete("finished"));
  res.on("close", () => {
    if (!res.writableEnded) complete("connection-closed");
  });

  return requestStorage.run({ requestId, req }, () => next());
};

module.exports = {
  errorContext,
  logEvent,
  logreq,
  requestContext,
};
