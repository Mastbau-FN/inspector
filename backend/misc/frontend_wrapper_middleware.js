const storage = require('node-persist');

const id_store = storage.create({dir: '__id_store', ttl: 604800000*100});//store entries for 100 weeks
id_store.init();

const frontend_to_backend_id_decorator = async (req, res, next) => {    
    req = await frontend_to_backend_id_decorator_inner(req)
    return next();
};

const frontend_to_backend_id_decorator_inner = async (req) => {  
    console.log('hihihi');  
    try {
       
        const frontend_id = req.body.data.local_id;
        await new Promise(resolve => setTimeout(resolve, 1000));
        const backend_id = await get_backend_id_from_frontend_id(frontend_id);
        //console.log("🚀 ~ file: frontend_wrapper_middleware.js:17 ~ constfrontend_to_backend_id_decorator_inner= ~ frontend_id", frontend_id)
        //console.log("🚀 ~ file: frontend_wrapper_middleware.js:17 ~ constfrontend_to_backend_id_decorator_inner= ~ backend_id", backend_id)


        if (backend_id) {

            req.body.data = {...req.body.data, ...backend_id} 
            
            return req;
        }
        console.log("backend_id nach if von backend id" + backend_id)
        if(req.body.data.parent_local_id){
            let backend_id = {E1:null,E2:null,E3:null};
            console.log("davor");
            let parentbackendid = await get_backend_id_from_frontend_id(req.body.data.parent_local_id);
            console.log("danach");
            if(parentbackendid.E1 != null){
                backend_id.E1 = parentbackendid.E1
            }
            if(parentbackendid.E2 != null){
                backend_id.E2 = parentbackendid.E2
            }
            if(parentbackendid.E3 != null){
                backend_id.E3 = parentbackendid.E3
            }    
            req.body.data = {...req.body.data, ...backend_id} 

            console.log("backend_id nach if von parent id" + backend_id)
        }
    } catch (error) {
        // console.warn("decorating id error", error)
        // res.status(400).json({ reason: "couldnt map local id to backend id, please contact admin" });
    }
    return req;
};

const get_backend_id_from_frontend_id = (frontend_id) => id_store.getItem(frontend_id);// {E1: 1, E2: 2, E3: 3}



const update_id_map = async (data)=>{
    let frontend_id = data.local_id;
    let backend_id = {E1: data.E1, E2:data.E2, E3:data.E3};
    //console.log("🚀 ~ file: frontend_wrapper_middleware.js:40 ~ constupdate_id_map= ~ frontend_id", frontend_id)
    
    //console.log("🚀 ~ file: frontend_wrapper_middleware.js:41 ~ constupdate_id_map= ~ backend_id", backend_id)
    await id_store.setItem(frontend_id, backend_id);
}



const hash_store = storage.create({dir: '__hash_store', ttl: 604800000*100});//store entries for 100 weeks
hash_store.init();

const frontend_to_backend_hash_decorator = async (req, res, next) => {
    try {
        // console.log("middlewarehashbefore:    ", req.body.hash)

        let frontend_hash = req.body.hash;

        let backend_hash = await hash_store.getItem(frontend_hash);
        // console.log("middlewarehashdanach:    ", backend_hash)
        if (backend_hash) {
            req.body.hash = backend_hash;
            // console.log(req.body, "fred feuerstein");
            return next();
        }
    } catch (error) {
        // res.status(400).json({ reason: "couldnt map local hash to backend hash, please contact admin" });
    }
    return next(); // nötig, da sonst bilder ohne hashmatch nicht als main gesetzt werden können
};

const update_hash_map = async (data, hash)=>{
    
    let frontend_hash = data.hash;
    
    let backend_hash = hash;
    console.log("🚀 ~ file: frontend_wrapper_middleware.js:54 ~ hash", hash)
    await hash_store.setItem(frontend_hash, backend_hash);
}


module.exports = {
    update_id_map: update_id_map,
    ftb_id_map: id_store,
    ftb_id: frontend_to_backend_id_decorator, 
    update_hash_map: update_hash_map,
    ftb_hash_map: hash_store,
    ftb_hash: frontend_to_backend_hash_decorator,
    ftb_ftb_id: frontend_to_backend_id_decorator_inner,
}