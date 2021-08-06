require('dotenv').config();

const api_wall = (req, res, next) => {
    if (!req.headers.authorization) {
        return res.status(403).json({ error: 'No auth header given' });
    }
    if (req.headers.authorization!=process.env.api_key) {
        return res.status(403).json({ error: 'NOT AUTHORIZED' });
    }
    next();
}

module.exports = {
    api_wall
}