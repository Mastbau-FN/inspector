const _hideProblems = false;

const _getImageFromHash_r = "/image/get";
const _uploadImage_r = "/image/set";

const _addNew_r = "/set";
const _update_r = "/update";
const _delete_r = "/delete";

const _deleteImageByHash_r = "/deleteImgH"; // issue #39
const _setMainImageByHash_r = "/setMainImgH"; // issue #20

const fs = require("fs");

var http = require("http");
var https = require("https");

const express = require("express");

require("dotenv").config();

//while(true){}

const multer = require("multer");
const upload = multer({ storage: require("./images/storage").mstorage });

const api = require("./api");

const ftb = require("./misc/frontend_wrapper_middleware");

const identifiers = require('./misc/identifiers').identifiers;

const {generateFieldParser} = require("./misc/json_helper");

const datapointRoutes = [
  { route: `/${identifiers.location}/get`, api: api.getProjects },
  { route: `/${identifiers.category}/get`, api: api.getCategories },
  { route: `/${identifiers.checkpoint}/get`, api: api.getCheckPoints },
  { route: `/${identifiers.defect}/get`, api: api.getCheckPointDefects },
];

const auth = require("./auth/auth");

const app = express();
const port = process.env.PORT || 443;

var cors = require("cors");
app.use(
  cors({
    origin: ["https://mastbau-fn.github.io"],
    credentials: true,
  })
);

app.use(function(req, res, next) {
  res.on('header', function() {
    console.trace('HEADERS GOING TO BE WRITTEN');
  });
  return next();
});

app.use(express.json());
app.use(
  express.urlencoded({
    extended: true,
  })
);

app.set("view engine", "ejs");
app.set("views", __dirname + "/views");

app.get("/", (request, response) => {
  response.render("index");
});

//multpart-middleware has to come before login, so the body is already parsed
app.post(
  "/api/secure" + _uploadImage_r,
  auth.api_wall,
  generateFieldParser(["data"]),//req.body.data = JSON.parse(req.body.data)
  ftb.ftb_id,
  upload.any(),
  //auth.login_wall, //TODO: reenable
  api.fileUpload
);

const isInsecure = process.env.isInsecure ?? false; //currently unused

/**
 * everything at this path (/api/secure/) is hidden behind an auth-wall currently requiring the correct authentication header (API-Key)
 *
 * its also very important to only expose this api via https since otherwise the auth data wouldn't be encrypted and anyone could steal the credentials
 */

// api-key wall
app.use("/api/secure/", auth.api_wall);

// needs a user to be logged in aka provided via the user param inside the post request
app.use("/api/secure/", auth.login_wall);


//log everything
const logger = require("./misc/logger");
app.use("/", logger.logreq);


app.post("/api/secure/login", api.login);

app.use("/api/secure/", ftb.ftb_id,ftb.ftb_hash);

datapointRoutes.forEach((datapointRoute) =>
  app.post("/api/secure" + datapointRoute.route, datapointRoute.api)
);

app.post("/api/secure" + _addNew_r, api.addNew);


app.post("/api/secure" + _update_r, api.update);
app.post("/api/secure" + _delete_r, api.delete_);


app.post("/api/secure" + _deleteImageByHash_r, api.deleteImgByHash);
app.post("/api/secure" + _setMainImageByHash_r, api.setMainImgByHash);

app.post("/api/secure" + _getImageFromHash_r, api.getFileFromHash);

app.get("/error", (req, res) => {
  throw Error("failed");
});

// MARK : 404
app.use(function (req, res, next) {
  res.status(404);

  // respond with html page
  if (req.accepts("html")) {
    res.render("404", { url: req.url });
    return;
  }

  // respond with json
  if (req.accepts("json")) {
    res.json({ error: "Not found" });
    return;
  }

  // default to plain-text. send()
  res.type("txt").send("Not found");
});

// MARK : 500

app.use("/api/", function (err, req, res, next) {
  console.error({ err });
  res.status(500).send({ error: _hideProblems ? "Something broke!" : err});
});

// // when an error accurs that should be human readable
// app.use(function (err, req, res, next) {
//   res.status(err.status || 500);
//   res.render("500", { error: err });
// });

if (isInsecure) {
  var httpServer = http.createServer(app);
  httpServer.listen(port, () => {
    console.warn(`App running on port ${port}. THIS IS INSECURE`);
  });
} else {
  const cert_path = process.env.CERT_PATH;
  const key = fs.readFileSync(cert_path + "privkey.pem");
  const cert = fs.readFileSync(cert_path + "cert.pem");
  var httpsServer = https.createServer({ key: key, cert: cert }, app);
  httpsServer.listen(port, () => {
    console.log(`App running on port ${port}.`);
  });
}
