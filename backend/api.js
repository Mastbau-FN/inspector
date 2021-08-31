const queries = require("./db/queries");

const login = (req,res)=>{
    let json_response = {'success':true};
    json_response.user = req.user;
    res.status(200).json(json_response);
}

const getProjects = async (req,res) => 
    res.status(200).json({inspections: await queries.getInspectionsForUser(req.user)});

const getCategories = async (req,res) => 
    res.status(200).json({categories: await queries.getCheckCategoriesForPjNR(req.body.PjNr)});
    
module.exports = {
    login,
    getProjects,
    getCategories,
}
