const storage = require('node-persist');

const id_store = storage.create({dir: '__id_store', ttl: 604800000*100});//store entries for 100 weeks
id_store.init();

const frontend_to_backend_id_decorator = async (req, res, next) => {
    try {
        let frontend_id = req.body.data.local_id;
        let backend_id = await id_store.getItem(frontend_id); // {E1: 1, E2: 2, E3: 3}
        if (backend_id) {
            req.body.data = {...req.body.data, ...backend_id} 
            next();
        }
    } catch (error) {
        res.status(400).json({ reason: "couldnt map local id to backend id, please contact admin" });
    }
    // next();
};

const update_id_map = (data)=>{
    let frontend_id = data.local_id;
    let backend_id = {E1: data.E1, E2:data.E2, E3:data.E3};
    id_store.setItem(frontend_id, backend_id);
}



const hash_store = storage.create({dir: '__hash_store', ttl: 604800000*100});//store entries for 100 weeks
hash_store.init();

const frontend_to_backend_hash_decorator = async (req, res, next) => {
    try {
        let frontend_hash = req.body.hash;
        let backend_hash = await hash_store.getItem(frontend_hash);
        if (backend_hash) {
            req.body.hash = backend_hash;
            next();
        }
    } catch (error) {
        res.status(400).json({ reason: "couldnt map local hash to backend hash, please contact admin" });
    }
    // next();
};

const update_hash_map = (data, hash)=>{
    console.log(data, "hhhhrzghfadsfasfasfasfasfasf")
    let frontend_hash = hash
    if(data!=null||data!=undefined){
        frontend_hash = data.hash;
    }
    
    let backend_hash = hash;
    hash_store.setItem(frontend_hash, backend_hash);
}


module.exports = {
    update_id_map: update_id_map,
    ftb_id_map: id_store,
    ftb_id: frontend_to_backend_id_decorator, 
    update_hash_map: update_hash_map,
    ftb_hash_map: hash_store,
    ftb_hash: frontend_to_backend_hash_decorator,
}