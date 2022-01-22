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
    //// delete data.rows.hashImagesAndCreateIds;
  
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

const _locationToString = (location)=>replaceUmlaute(`${location.Straße}, ${location.Straße}, ${location.Straße}`);


//see https://stackoverflow.com/a/54346022
const umlautMap = {
    '\u00dc': 'UE',
    '\u00c4': 'AE',
    '\u00d6': 'OE',
    '\u00fc': 'ue',
    '\u00e4': 'ae',
    '\u00f6': 'oe',
    '\u00df': 'ss',
  }

  function replaceUmlaute(str) {
    return str
      .replace(/[\u00dc|\u00c4|\u00d6][a-z]/g, (a) => {
        const big = umlautMap[a.slice(0, 1)];
        return big.charAt(0) + big.charAt(1).toLowerCase() + a.slice(1);
      })
      .replace(new RegExp('['+Object.keys(umlautMap).join('|')+']',"g"),
        (a) => umlautMap[a]
      );
  }