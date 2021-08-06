
require('dotenv').config();

const Pool = require('pg').Pool

let db = [];

db.pool = new Pool({
  user:  process.env.postgres_user,
  host: process.env.postgres_host,
  database: process.env.postgres_database,
  password: process.env.postgres_password,
  port: process.env.postgres_port
});

module.exports = {
  db
}