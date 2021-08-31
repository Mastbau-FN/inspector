////const bcrypt = require("bcrypt");
const fs = require('fs');
const fsp = fs.promises;
const pool = require('./pool').db.pool;

// MARK: Helpers

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
const queryFileWithParams = async (file,params)=>{
  let query = await getQueryString(file);
  let data = await pool.asyncQuery(query,params);
  return data.rows;
}

/**
 * 
 * @param {User} user 
 * @returns a Promise resolving all user data when the credentials are valid and throwing if not
 */
const getValidUser = async (user) => {
  let userdata = (await queryFileWithParams('auth_user', [user.name,user.pass]))[0];
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
 const getInspectionsForUser = (user) => queryFileWithParams('inspection_locations',[user.name,2000,6097]);

 /**
 * 
 * @param {Number} pjNr 
 * @returns a Promise resolving to all categories that need to be checked for a given project
 */
  const getCheckCategoriesForPjNR = (pjNr) => queryFileWithParams('check_categories',[pjNr]);

 /**
 * 
 * @param {Number} pjNr 
 * @param {Number} category_index 
 * @returns a Promise resolving to all points that need to be checked for a given category_index in a specific project
 */
  const getCheckPointsForPjNR = (pjNr,category_index) => queryFileWithParams('check_points',[pjNr,category_index]);

 /**
 * 
 * @param {Number} pjNr 
 * @param {Number} category_index 
 * @param {Number} check_point_index 
 * @returns a Promise resolving to all defects that were checked the check_point_index-th checkpoint for the category_index-th category in project number pjNr
 * TODO: ASKTHIS is this correct or only check_point_index needed?
 */
  const getCheckPointDefectsForPjNR = (pjNr,category_index,check_point_index) => queryFileWithParams('check_point_defects',[pjNr]);



module.exports = {
  getValidUser,
  getInspectionsForUser,
  getCheckCategoriesForPjNR,
  getCheckPointsForPjNR,
  getCheckPointDefectsForPjNR,
}