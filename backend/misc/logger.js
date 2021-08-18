const logreq = (req,res,next)=>{
    console.log(req.body)
    //TODO add some logging if wanted
    next();
}

module.exports = {
    logreq,
}