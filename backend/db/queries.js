////const bcrypt = require("bcrypt");
const fs = require("fs");
const fsp = fs.promises;

const path = require("path");

const pool = require("./pool").db.pool;

const imghasher = require("../images/hash");
const imgfiler = require("../images/filesystem");

// MARK: Helpers

//adding .last() for arrays
if (!Array.prototype.last) {
  Array.prototype.last = function () {
    return this[this.length - 1];
  };
}

/**
 *
 * example usage:
 * ```
 * await getQueryString('inspection_locations');
 * ```
 * returns the sql query in `./sql/inspection_locations.sql`
 */
const getQueryString = async (name) => {
  //change path here if folder structure changes
  return (await fsp.readFile(`./db/sql/${name}.sql`)).toString();
};

/**
 *
 * @param {String} file
 * @param {List} params
 * @returns a Promise resolving the data given by sql query name (uses {getQueryString}) with given parameters
 */
const queryFileWithParams = async (file, params, addHashFunction = true) => {
  let query = await getQueryString(file);
  let data = await pool.asyncQuery(query, params);

  if (addHashFunction) {
    data.rows.hashImages = async function () {
      return await hashImages(this);
    };
  }

  return data.rows;
};

/**
 *
 * @param {User} user
 * @returns a Promise resolving all user data when the credentials are valid and throwing if not
 */
const getValidUser = async (user) => {
  let userdata = (
    await queryFileWithParams("get/auth_user", [user.name, user.pass])
  )[0];
  if (userdata === undefined) {
    throw new Error("user credentials invalid");
  }
  userdata.PW = undefined; //remove PW hash, not needed actually
  return userdata;
};

/**
 *
 * @param {User} user
 * @returns a Promise resolving to all the inspection location data for the inspector given by {user.name} (with name beeing the kürzel)
 */
// TODO later: 2000 = inspections, 6097 = auch irgendeine nummer, die als parameter verwendet werden können später
const getInspectionsForUser = (user) =>
  queryFileWithParams("get/inspection_locations", [user.KZL, 2000, 6097]);

/**
 *
 * @param {Number} pjNr
 * @returns a Promise resolving to all categories that need to be checked for a given project
 */
const getCheckCategoriesForPjNR = (pjNr) =>
  queryFileWithParams("get/check_categories", [pjNr]);

/**
 *
 * @param {Number} pjNr
 * @param {Number} category_index
 * @returns a Promise resolving to all points that need to be checked for a given category_index in a specific project
 */
const getCheckPoints = (pjNr, category_index) =>
  queryFileWithParams("get/check_points", [pjNr, category_index]);

/**
 *
 * @param {Number} pjNr
 * @param {Number} category_index
 * @param {Number} check_point_index
 * @returns a Promise resolving to all defects that were checked the check_point_index-th checkpoint for the category_index-th category in project number pjNr
 */
const getCheckPointDefects = (pjNr, category_index, check_point_index) =>
  queryFileWithParams("get/check_point_defects", [
    pjNr,
    check_point_index,
    category_index,
  ]);

/**
 *
 * @param {Number} pjNr
 * @param category the new category that shall be added (name, description, link, linkOrdner)
 * @returns a Promise resolving to the new ID (E1)
 */
const addCheckCategory = (pjNr, category) =>
  queryFileWithParams("set/check_categories", [pjNr, ...category.values()]);

/**
 *
 * @param {Number} pjNr
 * @param {Number} category_index
 * @param check_point the new check_point that shall be added (name, description, link, linkOrdner)
 * @returns a Promise resolving to the new ID (E2)
 */
const addCheckPoint = (pjNr, category_index, check_point) =>
  queryFileWithParams("set/check_points", [
    pjNr,
    category_index,
    ...check_point.values(),
  ]);

/**
 *
 * @param {Number} pjNr
 * @param {Number} category_index
 * @param {Number} check_point_index
 * @param check_point_defect the new defect that shall be added (name, description, link, linkOrdner)
 * @returns a Promise resolving to the new ID (E3)
 */
const addCheckPointDefect = (
  pjNr,
  category_index,
  check_point_index,
  check_point_defect
) =>
  queryFileWithParams("set/check_point_defects", [
    pjNr,
    check_point_index,
    category_index,
    ...check_point_defect.values(),
  ]);

const getRootFolder = async (pjNr) =>
  path.dirname(
    convertpath(
      (await queryFileWithParams("root_folder", [pjNr], false))[0].Link ?? ""
    )
  );

const getLink = async (data) => {
  let convertpath = (winpath) =>
    winpath.split(path.win32.sep).join(path.posix.sep);

  let rootfolder = await getRootFolder(data.PjNr);

  let _link =
    data.Link ??
    (await pool.asyncQuery(
      ```
        SELECT 
          "Events"."Link"
        FROM 
          "MGAUFTR" INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"

        WHERE (
          ("MGAUFTR"."PjNr" = $1) -- projektnummer
          AND ("Events"."Link" IS NOT NULL) 
      ``` 
      + data.E1 != null ? 'AND ("Events"."E1" = ' + data.E1 + ")" : "" 
      + data.E2 != null ? 'AND ("Events"."E2" = ' + data.E2 + ")" : "" 
      + data.E3 != null ? 'AND ("Events"."E3" = ' + data.E3 + ")" : "" 
      +
      ```
        )

        ORDER BY "Events"."EREArt" DESC, "Events"."E1","Events"."E2","Events"."E3" ASC
        LIMIT 1 -- could be removed but im just interested in a sngle link sooo yeah
        ;
    
      ```,
      [data.PjNr]
    ).rows[0]); // this could throw if no link is found, TODO: err-handling

  let link = path.dirname(convertpath(_link));link = rootfolder == link ? "" : link;
  let mainImg = path.basename(convertpath(_link));

  return { rootfolder, link, mainImg };
};

module.exports = {
  getLink,

  getValidUser,
  getInspectionsForUser,
  getCheckCategoriesForPjNR,
  getCheckPoints,
  getCheckPointDefects,

  addCheckCategory,
  addCheckPoint,
  addCheckPointDefect,
};

const hashImages = async (tthis) => {
  for (thingy of tthis) {
    if (thingy.Link) {
      let rootfolder, link, mainImg;
      ({ rootfolder, link, mainImg } = await getLink(thingy));
      ////console.log({rootfolder,link,mainImg});

      // get all *other* image names
      let imageNames = (
        await imgfiler.getAllImagenamesFrom(rootfolder, link)
      ).filter((v) => v != mainImg);

      // append their hashes to the returned obj
      thingy.images = await Promise.all(
        imageNames.map(
          async (name) => await imghasher.memorize(rootfolder, link, name)
        )
      );

      // set main image at first index
      thingy.images.unshift(
        await imghasher.memorize(rootfolder, link, mainImg)
      );
    }
    // no longer needed
    delete thingy.Link;
    //never needed anyways
    delete thingy.LinkOrdner;
  }

  //// //selfdestruction muhhahah
  //// delete data.rows.hashImages;

  return tthis;
};
