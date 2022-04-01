////const bcrypt = require("bcrypt");
const options = require("../options");

const useNewID = true //&& false;
const _ID_ = useNewID ? 1910 : 6097;

const fs = require("fs");
const fsp = fs.promises;

const path = require("path");

const pool = require("./pool").db.pool;

const imghasher = require("../images/hash");
const imgfiler = require("../images/filesystem");

var assert = require('assert');

const identifiers = require('../misc/identifiers').identifiers;

// MARK: Helpers

//adding .last() for arrays
if (!Array.prototype.last) {
  Array.prototype.last = function () {
    return this[this.length - 1];
  };
}

const _nextID = async() => (await pool.asyncQuery(`SELECT coalesce(max("Index") + 1, 1) AS "Index" FROM "Events";`, null)).rows[0].Index;

const _removeHighestLevel = (data)=>{
  let data_copy = {...data};

  //remove highest event
  if (!data_copy.E1 > 0){
    throw Error("could not get parent, we already are the parent");
  } else if (!(data_copy.E2 > 0)) {
    data_copy.E1 = null;
  } else if(!(data_copy.E3 > 0)) {
    data_copy.E2 = null;
  } else {
    data_copy.E3 = null;
  }
  return data_copy;
}

const _addfoldername = async (data)=>{
  
  //let data_copy = _removeHighestLevel(data);
  data.Link = null;
  //to then get parent folder
  const {rootfolder, link, mainImg} = await getLink(data);

   //ODO: check if this worked
  data.Link = path.join(rootfolder,link,mainImg)
  data.LinkOrdner = path.join(rootfolder,link)

  return data;
}

Object.prototype.firstNonNull = (names) => {
  for (const key in names) {
    if (Object.hasOwnProperty.call(this, key) && this[key] != null) {
      return names[key];
    }
  }
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
const queryFileWithParams = async (file, params, addHashFunction = true, debug=false) => {
  let query = await getQueryString(file);
  let data = await pool.asyncQuery(query, params);

  if(debug)console.log(data)

  if (addHashFunction) {
    data.rows.hashImagesAndCreateIds = async function () {
      return await hashImagesAndCreateIds(this);
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
  queryFileWithParams("get/inspection_locations", [user.KZL, 2000, _ID_]);

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
 * @param KZL das kürzel des monteurs der diesen datenpunkt erstellt 
 * @returns a Promise resolving to the new ID (E1..E3)
 */
 const addNew = async (data, KZL) => {
   const folder = "set";
  let ld = data.data;
  let params;
  let queryfile;
  switch (data.type) {
    case identifiers.category:
      queryfile = folder+"/check_categories";
      params = [ld.PjNr, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner, KZL];
      break;
    case identifiers.checkpoint:
      queryfile = folder+"/check_points";
      params = [ld.PjNr, ld.E1, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner, KZL];
      break;
    case identifiers.defect:
      queryfile = folder+"/check_point_defects";
      params = [ld.PjNr, ld.E1, ld.E2, ld.KurzText, ld.LangText ?? "", ld.heigth , ld.EREArt ?? 5204, ld.Link, ld.LinkOrdner, KZL];
      break;
  
    default:
      console.log(`someone tried to add ${data.type}`);
      return;
  }
  let res = await queryFileWithParams(queryfile, params);
  const newdata = {...(data.data),...(res[0])}
  _addfoldername(newdata);
  return res;
}

/**
 *
 * this does pretty much the same as addNew
 * @param data consisting of type and data
 * @returns  an empty  Promise
 */
 const update = async (data) => {
  const folder = "update";
 let ld = data.data;
 let params;
 let queryfile;
 switch (data.type) {
   case identifiers.category:
     //console.log("updating category")
     //console.log(ld.Link);
     queryfile = folder+"/check_categories";
     params = [ld.PjNr, ld.E1, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner, ld.Zusatz_Info]; //Zusatz_Info ist momentan nur in den defects selbst im frontend setzbar (aber wer weiss vllt solls das ja mal geben)
     break;
   case identifiers.checkpoint:
     queryfile = folder+"/check_points";
     params = [ld.PjNr, ld.E1, ld.E2, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner, ld.Zusatz_Info]; //Zusatz_Info ist momentan nur in den defects selbst im frontend setzbar (aber wer weiss vllt solls das ja mal geben)
     break;
   case identifiers.defect:
     queryfile = folder+"/check_point_defects";
     params = [ld.PjNr, ld.E1, ld.E2, ld.E3, ld.KurzText, ld.LangText ?? "", ld.EREArt ?? 5204, ld.Link, ld.LinkOrdner, ld.Zusatz_Info];
     break;
  case identifiers.location:
    queryfile = folder+"/inspection_location";
    params = [ld.PjNr, ld.Eigentuemer,	ld.Bauwerkhoehe,	ld.Baujahr,	ld.Ansprechpartner,	ld.Steigwegtyp,	ld.Schluessel,	ld.Abschaltungen,	ld.Steckdosen,	ld.WC,	ld.Lagerraeume,	ld.Steigschutzschluess];
    params2 = [ld.PjNr, ld.KurzText, ld.LangText, ld.Link, ld.LinkOrdner, ld.Zusatz_Info];
    await queryFileWithParams(queryfile+"_part2", params2);
    break;
 
   default:
     console.log(`someone tried to update ${data.type}`);
     return;
 }
 let res = await queryFileWithParams(queryfile, params);
 res.success = true;
 return res;
}

/**
 *
 * @param data consisting of type and data where data has to have pjnr and dependent on its type E1-E3
 * @param KZL das kürzel des monteurs der diesen datenpunkt zu löschen versucht (kommt aud req.body.user)
 * @returns an empty  Promise
 */
const delete_ = async (data, KZL) => {
  let ld = data.data;

  /// checks if the given dta fits the type
  assert(
    (data.type == identifiers.category
      && ld.E1
      && !ld.E2
      && !ld.E3
    )
    ||
    (data.type == identifiers.checkpoint
      && ld.E1
      && ld.E2
      && !ld.E3
    )
    ||
    (data.type == identifiers.defect
      && ld.E1
      && ld.E2
      && ld.E3
    )
  )

  //console.log([ld.PjNr, ld.E1 ?? 0, ld.E2 ?? 0, ld.E3 ?? 0, KZL])
  let res = await queryFileWithParams("delete/delete", [ld.PjNr, ld.E1 ?? 0, ld.E2 ?? 0, ld.E3 ?? 0, KZL]).id;//, false,true);
  // console.log(res)
  res.success = true;
  return res;
}

const convertpath = (winpath) =>
  winpath.split(path.win32.sep).join(path.posix.sep);

const getRootFolder = async (pjNr) =>
{
  const queryRes = (await queryFileWithParams("get/root_folder", [pjNr,_ID_], false));//funzt
  const _rootdir = queryRes[0].firstNonNull({Link:0, LinkOrdner:0}) ?? ""
  return path.dirname(
    convertpath(_rootdir)
  );
}
  



// this function is just power pure
const getLink = async (data, andSet = true, recursion_num = 0) => {

  let rootfolder = await getRootFolder(data.PjNr);

  let _link =
    data.Link;
    
  if(_link == null){
    let qres = (await _magic_query(data)).rows[0];

    const _newFolderName = async (data)=>{
      const _backup = (await _magic_query(data,false)).rows[0];
      const new_name = (_backup.Index ?? "TODO_INDEX") + "_" + (_backup.KurzText ?? "TODO_KURZTEXT");
      return new_name;
    }


    // const parent_data = _removeHighestLevel(data); 
    // console.log(recursion_num+1, parent_data);      

    _link = path.join(
      ((qres?.Link ?? qres?.LinkOrdner) == null)                                  //if we dont get a result
        ? path.join(
          //okay, hier fängt der sich bestimmt in unendlicher recursion..   
          await((async()=>{
            try{return (await getLink(_removeHighestLevel(data),true,recursion_num+1)).link;}catch(e){console.warn(e);return "NO_LINK";}
          })())
            , //try the level above
            await _newFolderName(data)                                            //and add the new name
          )               
        : "" ,                                                                    //else were fine
      qres?.Link ?? path.join(qres?.LinkOrdner ?? "", "no_default_picture_yet")   //otherwise 
    );
  }

    
  let link = path.dirname(convertpath(_link));link = rootfolder == link ? "" : link;
  let mainImg = path.basename(convertpath(_link));

  const res = { rootfolder, link, mainImg };

  if(andSet)_magic_setLink(data,res);

  return res;
};

const deleteImgByHash = async (hash)=>{
  let p = imghasher.getPathFromHash(hash);
  //console.log(p)
  //TODO: errorhandling
  const oldpath = imgfiler.formatpath(path.join(p.rootpath, p.link, p.filename));
  const newDir = imgfiler.formatpath(path.join(p.rootpath, p.link, './.deleted/'));
  try {
    await fsp.mkdir(newDir)
  } catch (error) {
    
  }
  const newpath = imgfiler.formatpath(path.join(p.rootpath, p.link, './.deleted/' , p.filename));
  console.log(oldpath,newpath)
  let ret = await fsp.rename( oldpath , newpath );
  return {response: ret}
}


module.exports = {
  getLink,

  getValidUser,
  getInspectionsForUser,
  getCheckCategoriesForPjNR,
  getCheckPoints,
  getCheckPointDefects,

  addNew,
  update,
  delete_,

  deleteImgByHash,
};

const hashImagesAndCreateIds = async (tthis) => {
  // console.log({hashing: tthis})
  for (var thingy of tthis) {
    if (thingy.Link) {
      let { rootfolder, link, mainImg } = await getLink(thingy);

      // get all *other* image names
      let imageNames = (
        await imgfiler.getAllImagenamesFrom(rootfolder, link)
      ).filter((v) => v != mainImg);

      // append their hashes to the returned obj
      const images = 
        imageNames.map(
          (name) => {try{let x = imghasher.memorize(rootfolder, link, name); if(options.debugImageHashes)console.log(`${name} -> ${x}`); return x;}catch(e){console.log('failed to memorize something'+e);return "error_ could not fetch this image";}}
        )
      || ["error_ image hashing failed to-te-totally"];
      // console.log(images)

      // set main image at first index
      let mainHash = imghasher.memorize(rootfolder, link, mainImg);
      images.unshift(mainHash);

      thingy['images'] = images??["error_ couldnt set image hashes"];
      if(options.debugImageHashes)console.log(`imagehashes- ${thingy.KurzText ?? thingy.PjName ?? thingy.LangText ?? thingy.Index} -:`, thingy.images, {mainImg,mainHash});
  }
    thingy.local_id = `${thingy.KurzText}--${thingy.PjNr}-${thingy.E1}-${thingy.E2}-${thingy.E3}`
    // no longer needed
    delete thingy.Link;
    //never needed anyways
    delete thingy.LinkOrdner;
  }

  //// //selfdestruction muhhahah
  //// delete data.rows.hashImagesAndCreateIds;

  return tthis;
};



const __magic_part = (data)=>
  (data.E1 > 0 
    ? `AND ("Events"."E1" = $2::int)` 
      + (data.E2 > 0 
        ? `AND ("Events"."E2" = $3::int)` 
          + (data.E3 > 0 
            ? `AND ("Events"."E3" = $4::int)` 
              + `AND ("Events"."EREArt" >= 5201 AND "Events"."EREArt" <= 5204)` //all set -> search a Mangel (5201-5204)

            : `AND ("Events"."EREArt" = 5200)` //E3 not set -> search a PruefPunkt (5200)
            )
        : `AND ("Events"."EREArt" = 5100)` //E2 not set -> search a Category (5100)
        )
    : `AND ("Events"."EventID" = 1910)`//E1 not set -> search for a Location //also see issue #90
  )
  +  `AND ($2=$2 AND $3=$3 AND $4=$4)`;

/**
 * 
 * this query is used to update the Link and LinkOrdner, by identifying it via its event levels instead of an index
 * @returns nothing really
 */
const _magic_setLink = (data, {link, mainImg})=>pool.asyncQuery(
  `
    UPDATE
     "Events"

     SET "Link" = $6::varchar, "LinkOrdner" = $5::varchar

    WHERE (
      "Events"."PjNr" = $1 -- projektnummer
      AND ($6=$6 AND $5=$5) -- so the amount of params match
      -- AND "Link" IS NULL AND "LinkOrdner" IS NULL 
  `
  + __magic_part(data)
  +`);`,

  [data.PjNr,data.E1 ?? 0,data.E2??0,data.E3??0,link,path.join(link,mainImg)]
);

const _magic_query = (data,hasLink = true)=>pool.asyncQuery(
  `
    SELECT 
      "Events".*
    FROM 
      "MGAUFTR" INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"

    WHERE (
      ("MGAUFTR"."PjNr" = $1) -- projektnummer
      AND ($4=$4) -- so the amount of params match
  `
  + (hasLink 
    ?
      `
        AND ("Events"."Link" IS NOT NULL OR "Events"."LinkOrdner" IS NOT NULL) 
      `
    : ``
  )
  + __magic_part(data)+
  `
    )

    ORDER BY "Events"."EREArt" DESC, "Events"."E1","Events"."E2","Events"."E3" ASC
    LIMIT 1 -- could be removed but im just interested in a sngle link sooo yeah
    ;

  `,
  [data.PjNr,data.E1 ?? 0,data.E2??0,data.E3??0]
);
