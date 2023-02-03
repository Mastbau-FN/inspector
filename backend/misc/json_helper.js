const parseFields = (fields, data) => {
  fields.forEach((field) => {
    try {
      data[field] = JSON.parse(data[field]);
    } catch (_) {}
  });
  return data;
};

const generateFieldParser = (fields) => {
  return (req, res, next) => {
    req.body = parseFields(fields, req.body);
    return next();
  };
};

module.exports = {
  parseFields,
  generateFieldParser,
};
