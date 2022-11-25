const storage = require('node-persist');
const myStorage = storage.create({dir: 'myDir', ttl: 604800000*100});//store entries for 100 weeks
myStorage.init();


const frontend_to_backend_id_decorator = (req, res, next) => {
    try {
        let frontend_id = req.body.data.local_id;
        let backend_id = myStorage.getItem(frontend_id); // {E1: 1, E2: 2, E3: 3}
        if (backend_id) {
            req.body.data = {...req.body.data, ...backend_id} 
            next();
        }
    } catch (error) {
        res.status(400).json({ reason: "couldnt map local id to backend id, please contact admin" });
    }
    // next();
};

const update_map = (data)=>{
    let frontend_id = data.local_id;
    let backend_id = {E1: data.E1, E2:data.E2, E3:data.E3};
    myStorage.setItem(frontend_id, backend_id);
}

module.exports = {
    update_map,
    ftb_id_map: myStorage,
    ftb_id: frontend_to_backend_id_decorator, 
}