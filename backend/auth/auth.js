require('dotenv').config();
const db = require('../db/queries')

const api_wall = (req, res, next) => {
    if (!req.headers.authorization) {
        return res.status(401).json({ error: 'No auth header given' });
    }
    if (req.headers.authorization!=process.env.api_key) {
        return res.status(403).json({ error: 'NOT AUTHORIZED' });
    }
    next();
}

const login_wall = async (req, res, next) => {
    const loginFreePaths = [''];
    if (loginFreePaths.includes(req.path)) return next();
    try {
        if (await db.isValidUser(req.body.user))next();
        else res.status(403).json({ error: 'wrong credentials' });
    }catch(e){
        return res.status(403).json({ error: 'no user provided' });
    }
}

module.exports = {
    api_wall,
    login_wall
}