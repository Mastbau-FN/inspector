function _newRequestId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

const logreq = (req, res, next) => {
  const requestId = _newRequestId();
  req.__request_id = requestId;

  const path = req.originalUrl ?? req.url;
  res.on("finish", () => {
    if (res.statusCode >= 400) {
      console.log(`[request] ${res.statusCode} ${req.method} ${path} req=${requestId}`);
    }
  });

  return next();
};

module.exports = {
  logreq,
};
