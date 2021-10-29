////const bcrypt = require("bcrypt");

//TODO: update-queries (wahrscheinlich nur LangText, der rest ist final)

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

const _addfoldername = async (data)=>{
  
  let data_copy = {...data};

  //remove highest event
  if (!(data_copy.E2 > 0)) {
    data_copy.E1 = null;
  } else if(!(data_copy.E3 > 0)) {
    data_copy.E2 = null;
  } else {
    data_copy.E3 = null;
  }
  data.Link = null;
  //to then get parent folder
  const {rootfolder, link, mainImg} = await getLink(data_copy);

  //TODO: check if this worked
  data.Link = path.join(rootfolder,link,"TODO_TEST_1"+data.KurzText,"no_default_picture_yet")
  data.LinkOrdner = path.join(rootfolder,link,"TODO_TEST_1"+data.KurzText)

  return data;
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
 * @param data consisting of type and data
 * @returns a Promise resolving to the new ID (E1..E3)
 */
const addNew = async (data) => {
  const ld = await _addfoldername(data.data);
  let params;
  let queryfile;
  switch (data.type) {
    case 'category':
      queryfile = "set/check_categories";
      params = [ld.PjNr, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner];
      break;
    case 'checkpoint':
      queryfile = "set/check_points";
      params = [ld.PjNr, ld.E1, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner];
      break;
    case 'defect':
      queryfile = "set/check_point_defects";
      params = [ld.PjNr, ld.E1, ld.E2, ld.KurzText, ld.LangText ?? "", ld.heigth ?? "no_height", ld.EREArt ?? 5204, ld.Link, ld.LinkOrdner];
      break;
  
    default:
      console.log(`someone tried to add ${data.type}`);
      return;
  }
  let res = await queryFileWithParams(queryfile, params);
  console.log(res);
  return res;
}

const convertpath = (winpath) =>
  winpath.split(path.win32.sep).join(path.posix.sep);

const getRootFolder = async (pjNr) =>
  path.dirname(
    convertpath(
      (await queryFileWithParams("get/root_folder", [pjNr], false))[0].Link ?? ""
    )
  );

const getLink = async (data) => {

  let rootfolder = await getRootFolder(data.PjNr);
  //console.log(rootfolder);

  let _link =
    data.Link;
    
  if(_link == null){
    let qres = (await pool.asyncQuery(
      `
        SELECT 
          "Events"."Link", "Events"."LinkOrdner"
        FROM 
          "MGAUFTR" INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"

        WHERE (
          ("MGAUFTR"."PjNr" = $1) -- projektnummer
          AND ("Events"."Link" IS NOT NULL OR "Events"."LinkOrdner" IS NOT NULL) 
      `
      // if this field is available we check if it matches otherwise query the level above and ignore parameter
      + (data.E1 > 0 ? `AND ("Events"."E1" = $2)` : `AND ("Events"."EREArt" < 5199) AND ($2 = $2)` )
      + (data.E2 > 0 ? `AND ("Events"."E2" = $3)` : `AND ("Events"."EREArt" < 5200) AND ($3 = $3)` )
      + (data.E3 > 0 ? `AND ("Events"."E3" = $4)` : `AND ("Events"."EREArt" < 5201) AND ($4 = $4)` )
      +
      `
        )

        ORDER BY "Events"."EREArt" DESC, "Events"."E1","Events"."E2","Events"."E3" ASC
        LIMIT 1 -- could be removed but im just interested in a sngle link sooo yeah
        ;
    
      `,
      [data.PjNr,data.E1 ?? 0,data.E2??0,data.E3??0]
    )).rows[0];

    _link = qres?.Link ?? path.join(qres?.LinkOrdner ?? "", "no_default_picture_yet"); // this could throw if no link is found, TODO: err-handling
  }
    


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

  addNew,
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
