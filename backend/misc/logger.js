function _newRequestId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function _parseDataField(data) {
  if (data == null) return null;
  if (typeof data === "string") {
    try {
      return JSON.parse(data);
    } catch (_) {
      return null;
    }
  }
  if (typeof data === "object") return data;
  return null;
}

function _summarizeBody(body) {
  if (body == null || typeof body !== "object") return {};

  const out = {};
  if (body.type != null) out.type = body.type;
  if (body.hash != null) out.hash = body.hash;
  if (body.PjNr != null) out.PjNr = body.PjNr;
  if (body.E1 != null) out.E1 = body.E1;
  if (body.E2 != null) out.E2 = body.E2;
  if (body.E3 != null) out.E3 = body.E3;

  const data = _parseDataField(body.data);
  if (data != null) {
    if (data.PjNr != null) out.PjNr = data.PjNr;
    if (data.E1 != null) out.E1 = data.E1;
    if (data.E2 != null) out.E2 = data.E2;
    if (data.E3 != null) out.E3 = data.E3;
    if (data.local_id != null) out.local_id = data.local_id;
    if (data.parent_local_id != null) out.parent_local_id = data.parent_local_id;
  }

  const user = body.user;
  if (user && typeof user === "object") {
    out.user = user.name ?? user.KZL ?? user.kzl ?? null;
  }

  return out;
}

const logreq = (req, res, next) => {
  const startedAt = Date.now();
  const requestId = _newRequestId();
  req.__request_id = requestId;

  const path = req.originalUrl ?? req.url;
  const isUploadRoute = path.includes("/api/secure/image/set");

  if (isUploadRoute) {
    console.log(
      "[request] start",
      JSON.stringify({
        request_id: requestId,
        method: req.method,
        path,
        body: _summarizeBody(req.body),
      })
    );
  }

  res.on("finish", () => {
    if (isUploadRoute || res.statusCode >= 400) {
      console.log(
        "[request] end",
        JSON.stringify({
          request_id: requestId,
          method: req.method,
          path,
          status: res.statusCode,
          duration_ms: Date.now() - startedAt,
        })
      );
    }
  });

  return next();
};

module.exports = {
  logreq,
};
