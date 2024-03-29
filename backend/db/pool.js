require("dotenv").config();

const Pool = require("pg").Pool;

let db = [];

db.pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.POSTGRES_HOST,
  database: process.env.POSTGRES_DATABASE,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.POSTGRES_PORT,
});
db.pool.asyncQuery = (querystring, args) =>
  new Promise((resolve, reject) => {
    db.pool.query(querystring, args, (err, data) => {
      if (err) reject(err);
      resolve(data);
    });
  });

module.exports = {
  db,
};
