const fs = require('fs');
const key = fs.readFileSync('./key.pem');
const cert = fs.readFileSync('./cert.pem');
const https = require('https');

const express = require('express')
const bodyParser = require('body-parser')

require('dotenv').config();

const db = require('./db/queries')
const auth = require('./auth/auth')

const app = express()
const server = https.createServer({key: key, cert: cert }, app);
const port = process.env.port

app.use(bodyParser.json())
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
)

app.get('/', (request, response) => {
    response.json({ info: 'API for the inspections app, not meant for human consumption' })
})

/** 
 * everything at this path (/api/secure/) is hidden behind an auth-wall currently requiring the correct authentication header (API-Key)
 * can be disabled for testing purposes
*/
if (!process.env.insecure){
    app.use('/api/secure/', auth.api_wall);
    app.use('/api/secure/', auth.login_wall);
}

//log everything
const logger = require('./misc/logger');
app.use('/',logger.logreq);

app.post('/api/secure/login',(req,res)=>{
  let json_response = {'success':true};
  json_response.user = req.user;
  res.status(200).json(json_response);
});

server.listen(port+1, () => {
    console.log(`App running on port ${port}.`)
})
app.listen(port, () => {
  console.warn(`App running on port ${port}. THIS IS INSECURE`)//TODO remove http and force https
})
