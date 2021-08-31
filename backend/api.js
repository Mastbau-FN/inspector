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

const getCheckPoints = async (req,res) => 
    res.status(200).json({checkpoints: await queries.getCheckPoints(req.body.PjNr,req.body.E1)});

const getCheckPointDefects = async (req,res) => 
    res.status(200).json({checkpointdefects: await queries.getCheckPointDefects(req.body.PjNr,req.body.E1,req.body.E2)});


module.exports = {
    login,
    getProjects,
    getCategories,
    getCheckPoints,
    getCheckPointDefects
}
