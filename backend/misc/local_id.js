function _toNullableInt(v) {
  if (v == null) return null;
  if (typeof v === "number") return Number.isFinite(v) ? Math.trunc(v) : null;
  if (typeof v !== "string") return null;
  const s = v.trim();
  if (!s || s === "null" || s === "undefined") return null;
  const n = Number.parseInt(s, 10);
  return Number.isFinite(n) ? n : null;
}

function parseLocalId(localId) {
  if (typeof localId !== "string") return null;
  const s = localId.trim();
  // exclude purely local ids like "__loc__..." or other non-numeric prefixes
  if (!/^\d+(-|$)/.test(s)) return null;

  const parts = s.split("-");
  const pjNr = _toNullableInt(parts[0]);
  if (!(pjNr > 0)) return null;

  const e1 = _toNullableInt(parts[1]);
  const e2 = _toNullableInt(parts[2]);
  const e3 = _toNullableInt(parts[3]);

  return { PjNr: pjNr, E1: e1, E2: e2, E3: e3 };
}

function decorateDataFromLocalId(data) {
  if (!data || typeof data !== "object") return data;

  const parsed = parseLocalId(data.local_id);
  if (parsed) {
    if (data.PjNr == null) data.PjNr = parsed.PjNr;
    if (data.E1 == null) data.E1 = parsed.E1;
    if (data.E2 == null) data.E2 = parsed.E2;
    if (data.E3 == null) data.E3 = parsed.E3;
  }

  // parent_local_id: fill in missing event levels from parent.
  const parentParsed = parseLocalId(data.parent_local_id);
  if (parentParsed) {
    if (data.PjNr == null) data.PjNr = parentParsed.PjNr;
    if (data.E1 == null) data.E1 = parentParsed.E1;
    if (data.E2 == null) data.E2 = parentParsed.E2;
    if (data.E3 == null) data.E3 = parentParsed.E3;
  }

  return data;
}

function decorateReqFromLocalId(req, _res, next) {
  try {
    if (req?.body?.data && typeof req.body.data === "object") {
      req.body.data = decorateDataFromLocalId(req.body.data);
    }
  } catch (_) {}
  return next();
}

module.exports = {
  parseLocalId,
  decorateDataFromLocalId,
  decorateReqFromLocalId,
};

