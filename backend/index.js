const _getProjects_r = "/projects/get";
const _getCategories_r = "/categories/get";
const _getCheckPoints_r = "/checkPoints/get";
const _getCheckPointDefects_r = "/checkPointDefects/get";

const _getImageFromHash_r = "/image/get";
const _uploadImage_r = "/image/set";

const _addNew_r = "/set";

const fs = require("fs");

var http = require("http");
var https = require("https");

const express = require("express");

require("dotenv").config();

const multer = require("multer");
const upload = multer({ storage: require("./images/storage").mstorage });

const api = require("./api");
const auth = require("./auth/auth");

const app = express();
const port = process.env.PORT || 443;

var cors = require('cors');
app.use(cors({
    origin: ["https://mastbau-fn.github.io"],
    credentials: true,
}));

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

const isInsecure = process.env.isInsecure ?? false;

/**
 * everything at this path (/api/secure/) is hidden behind an auth-wall currently requiring the correct authentication header (API-Key)
 *
 * its also very important to only expose this api via https since otherwise the auth data wouldn't be encrypted and anyone could steal the credentials
 */

// api-key wall
app.use("/api/secure/", auth.api_wall);

//TODO: make sure no non-logged in user can access this...
app.post(
  "/api/secure" + _uploadImage_r,
  upload.any(),
  api.fileUpload
);

// needs a user to be logged in aka provided via the user param inside the post request
app.use("/api/secure/", auth.login_wall);

//log everything
const logger = require("./misc/logger");
app.use("/", logger.logreq);

app.post("/api/secure/login", api.login);

app.post("/api/secure" + _getProjects_r, api.getProjects);
app.post("/api/secure" + _getCategories_r, api.getCategories);
app.post("/api/secure" + _getCheckPoints_r, api.getCheckPoints);
app.post("/api/secure" + _getCheckPointDefects_r, api.getCheckPointDefects);

app.post("/api/secure" + _addNew_r, api.addNew);

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
  console.error({err});
  res.status(500).send({ error: "Something broke!" });
});

// when an error accurs that should be human readable
app.use(function (err, req, res, next) {
  res.status(err.status || 500);
  res.render("500", { error: err });
});


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
