const logreq = (req,res,next)=>{
    //TODO add some logging if wanted
    next();
}

module.exports = {
    logreq,
}