////const bcrypt = require("bcrypt");
const fs = require('fs');
const fsp = fs.promises;

const path = require('path');

const pool = require('./pool').db.pool;

const imghasher = require('../images/hash');
const imgfiler  = require('../images/filesystem');

// MARK: Helpers

//adding .last() for arrays
if (!Array.prototype.last){
  Array.prototype.last = function(){
      return this[this.length - 1];
  };
};

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
  return (await fsp.readFile(`./db/sql/${name}.sql`)).toString()
} 

/**
 * 
 * @param {String} file
 * @param {List} params
 * @returns a Promise resolving the data given by sql query name (uses {getQueryString}) with given parameters
 */
const queryFileWithParams = async (file,params, addHashFunction = true)=>{
  let query = await getQueryString(file);
  let data = await pool.asyncQuery(query,params);

  if (addHashFunction){
    data.rows.hashImages = async function(){return await hashImages(this)};
  }

  return data.rows;
}

/**
 * 
 * @param {User} user 
 * @returns a Promise resolving all user data when the credentials are valid and throwing if not
 */
const getValidUser = async (user) => {
  let userdata = (await queryFileWithParams('get/auth_user', [user.name,user.pass]))[0];
  if (userdata === undefined){
    throw new Error('user credentials invalid');
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
 const getInspectionsForUser = (user) => queryFileWithParams('get/inspection_locations',[user.KZL,2000,6097]);

 /**
 * 
 * @param {Number} pjNr 
 * @returns a Promise resolving to all categories that need to be checked for a given project
 */
  const getCheckCategoriesForPjNR = (pjNr) => queryFileWithParams('get/check_categories',[pjNr]);

 /**
 * 
 * @param {Number} pjNr 
 * @param {Number} category_index 
 * @returns a Promise resolving to all points that need to be checked for a given category_index in a specific project
 */
  const getCheckPoints = (pjNr,category_index) => queryFileWithParams('get/check_points',[pjNr,category_index]);

 /**
 * 
 * @param {Number} pjNr 
 * @param {Number} category_index 
 * @param {Number} check_point_index 
 * @returns a Promise resolving to all defects that were checked the check_point_index-th checkpoint for the category_index-th category in project number pjNr
 */
  const getCheckPointDefects = (pjNr,category_index,check_point_index) => queryFileWithParams('get/check_point_defects',[pjNr,check_point_index,category_index]);



module.exports = {
  getValidUser,
  getInspectionsForUser,
  getCheckCategoriesForPjNR,
  getCheckPoints,
  getCheckPointDefects,
}




const hashImages = async (tthis) => {
  for(thingy of tthis){

    if (thingy.Link){

      let convertpath = winpath => winpath.split(path.win32.sep).join(path.posix.sep);

      let rootfolder = path.dirname(convertpath((await queryFileWithParams('root_folder',[thingy.PjNr],false))[0].Link ?? ''));
      let link = path.dirname(convertpath(thingy.Link)); link = rootfolder == link ? '' : link;
      let mainImg = path.basename(convertpath(thingy.Link));

      ////console.log({rootfolder,link,mainImg});

      // get all *other* image names
      let imageNames = (await imgfiler.getAllImagenamesFrom(rootfolder,link))
        .filter((v)=>v!=mainImg);

      // append their hashes to the returned obj
      thingy.images = await Promise.all(imageNames.map(async name => 
        await imghasher.memorize(rootfolder,link,name)
      ));

      // set main image at first index
      thingy.images.unshift(await imghasher.memorize(rootfolder,link,mainImg));

    }
    // no longer needed
    delete thingy.Link;
    //never needed anyways
    delete thingy.LinkOrdner;
  }

  //// //selfdestruction muhhahah
  //// delete data.rows.hashImages;

  return tthis;
}