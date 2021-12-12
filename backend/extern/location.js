const axios = require('axios');

const getLocations = async (locationList) => {
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
            
            location.locations = queryres.results[0].locations;
        } catch (error) {
            console.warn(error);
            continue;
        }
    }
  
    //// //selfdestruction muhhahah
    //// delete data.rows.hashImages;
  
    return locationList;
};

const getCoords = async (locationList) => {
    await getLocations(locationList);
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
    getCoords,
    getLocations,
};

const _locationToString = (location)=>`${location.Straße}, ${location.Straße}, ${location.Straße}`;