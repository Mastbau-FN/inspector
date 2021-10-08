const queries = require("./db/queries");
const imagehandler = require("./images/hash");

const login = (req,res)=>{
    let json_response = {'success':true};
    json_response.user = req.user;
    res.status(200).json(json_response);
}

const getProjects = async (req,res) => 
    res.status(200).json({inspections: await(await queries.getInspectionsForUser(req.user)).hashImages()});

const getCategories = async (req,res) => 
    res.status(200).json({categories: await(await queries.getCheckCategoriesForPjNR(req.body.PjNr)).hashImages()});

const getCheckPoints = async (req,res) => 
    res.status(200).json({checkpoints: await(await queries.getCheckPoints(req.body.PjNr,req.body.E1)).hashImages()});

const getCheckPointDefects = async (req,res) => 
    res.status(200).json({checkpointdefects: await(await queries.getCheckPointDefects(req.body.PjNr,req.body.E1,req.body.E2)).hashImages()});

const getFileFromHash = async (req,res) => {
    try{
        let img = await imagehandler.getFileFromHash(req.body.imghash)
        res.writeHead(200,{'Content-type':'image/jpg'});
        res.end(img);
    }catch(e){
        res.status(404).json({reason: 'image no longer available'})
    }
}

const fileUpload = async (req, res) => {
    if (!req.file) {
        res.status(400).json({reason: 'no file uploaded'})
    }else{
        res.status(204).json()
    }
}


module.exports = {
    fileUpload,
    login,
    getProjects,
    getCategories,
    getCheckPoints,
    getCheckPointDefects,
    getFileFromHash,
}
