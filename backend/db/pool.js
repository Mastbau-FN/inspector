
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
db.pool.asyncQuery = (querystring,args)=> 
  new Promise(
    (resolve,reject)=>{
      db.pool.query(querystring,args, 
        (err,data)=>{
          if (err) reject(err);
          resolve(data);
        }
      )
    }
  )

module.exports = {
  db
}