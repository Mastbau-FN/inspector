const logreq = (req,res,next)=>{
    var passTmp;
    try {
        passTmp = req.body.user.pass;
        req.body.user.pass = '--CENSORED--';
    } catch (error) {}
    if(!req.url.includes('image')){
        console.log(`${req.url}:`, req.body)
    }
    try {
        req.body.user.pass = passTmp;
    } catch (error) {}
    return next();
 }

module.exports = {
    logreq,
}