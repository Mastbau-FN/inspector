const axios = require('axios');

const addLocations = async (locationList) => {
    for (location of locationList) {
        if (!( true 
            && location.Straße
            && location.PLZ
            && location.Ort
        )) continue;

        let queryres;
        try {
            queryres = await axios.post(`http://open.mapquestapi.com/geocoding/v1/address?key=${process.env.MAPQUEST_KEY}`, {
                location: _locationToString(location)
            });
            //console.log(queryres.data)//TODO:remove
            location.locations = queryres.data.results[0].locations;
        } catch (error) {
            console.warn(error);
            continue;
        }
    }
  
    //// //selfdestruction muhhahah
    //// delete data.rows.hashImages;
  
    return locationList;
};

const addCoords = async (locationList) => {
    await addLocations(locationList);
    for (location of locationList) {
        if (!(location.locations)) continue;

        try {
            location.latLng = location.locations[0].latLng;           
            delete location.locations;
        } catch (error) {
            //console.warn(error);
            continue;
        }
    }
    return locationList;
};

module.exports = {
    addCoords,
    addLocations,
};

const _locationToString = (location)=>`${location.Straße}, ${location.Straße}, ${location.Straße}`;