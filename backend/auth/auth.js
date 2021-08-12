require('dotenv').config();
const db = require('./db/queries')

const api_wall = (req, res, next) => {
    if (!req.headers.authorization) {
        return res.status(401).json({ error: 'No auth header given' });
    }
    if (req.headers.authorization!=process.env.api_key) {
        return res.status(403).json({ error: 'NOT AUTHORIZED' });
    }
    next();
}

const user_wall = (req, res, next) => {
    const loginFreePaths = ['/api/secure/login'];
    if (loginFreePaths.includes(req.path)) return next();
    isValidUser(user, next,()=>{return res.status(403).json({ error: 'user NOT AUTHORIZED' });})
}

module.exports = {
    api_wall,
    user_wall
}