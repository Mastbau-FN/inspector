const queries = require("./db/queries");
const imagehandler = require("./images/hash");

const login = (req,res)=>{
    let json_response = {'success':true};
    json_response.user = req.user;
    res.status(200).json(json_response);
}

const getProjects = async (req,res) => 
    res.status(200).json({inspections: (await queries.getInspectionsForUser(req.user)).hashImages()});

const getCategories = async (req,res) => 
    res.status(200).json({categories: (await queries.getCheckCategoriesForPjNR(req.body.PjNr)).hashImages()});

const getCheckPoints = async (req,res) => 
    res.status(200).json({checkpoints: (await queries.getCheckPoints(req.body.PjNr,req.body.E1)).hashImages()});

const getCheckPointDefects = async (req,res) => 
    res.status(200).json({checkpointdefects: (await queries.getCheckPointDefects(req.body.PjNr,req.body.E1,req.body.E2)).hashImages()});

const getFileFromHash = async (req,res) => {
    res.writeHead(200,{'Content-type':'image/jpg'});
    res.end(await imagehandler.getFileFromHash(req.body.imghash));
}


module.exports = {
    login,
    getProjects,
    getCategories,
    getCheckPoints,
    getCheckPointDefects,
    getFileFromHash,
}
