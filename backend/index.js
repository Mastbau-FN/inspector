const fs = require('fs');
const key = fs.readFileSync('./key.pem');
const cert = fs.readFileSync('./cert.pem');
const https = require('https');

const express = require('express')
const bodyParser = require('body-parser')

require('dotenv').config();

const api = require('./api')
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

app.set('view engine', 'ejs');
app.set('views', __dirname + '/views');

app.get('/', (request, response) => {
    response.render('index');
})

/** 
 * everything at this path (/api/secure/) is hidden behind an auth-wall currently requiring the correct authentication header (API-Key)
 * can be disabled for testing purposes
 * 
 * very important later though, since otherwise everybody can read and write data 
 * its also very important to only expose this api via https since otherwise the auth data wouldn't be encrypted and anyone could steal the credentials
*/
if (!process.env.insecure){
    // api-key wall
    app.use('/api/secure/', auth.api_wall);
    // needs a user to be logged in aka provided via the user param inside the post request 
    app.use('/api/secure/', auth.login_wall);
}

//log everything
const logger = require('./misc/logger');
app.use('/',logger.logreq);

app.post('/api/secure/login',api.login);

app.post('/api/secure/getProjects',api.getProjects);


app.get('/error',(req,res)=>{
  throw Error('failed');
})


// MARK : 404
app.use(function(req, res, next) {
  res.status(404);

  // respond with html page
  if (req.accepts('html')) {
    res.render('404', { url: req.url });
    return;
  }

  // respond with json
  if (req.accepts('json')) {
    res.json({ error: 'Not found' });
    return;
  }

  // default to plain-text. send()
  res.type('txt').send('Not found');
});

// MARK : 500

// when an error accurs that should be human readable
app.use(function(err, req, res, next){
  res.status(err.status || 500);
  res.render('500', { error: err });
});

app.use('/api/',function(err, req, res, next) {
  console.error(err);
  res.status(500).send({error: 'Something broke!'});
});

server.listen(port+1, () => {
    console.log(`App running on port ${port}.`)
})
app.listen(port, () => {
  console.warn(`App running on port ${port}. THIS IS INSECURE`)//TODO remove http and force https
})
