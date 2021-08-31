const queries = require("./db/queries");

const login = (req,res)=>{
    let json_response = {'success':true};
    json_response.user = req.user;
    res.status(200).json(json_response);
}

const getProjects = async (req,res) => res.json(await queries.getInspectionsForUser(req.user));

module.exports = {
    login,
    getProjects,
}