OBJECTIVE:

Local storage of relevant OpenStreetMap Data,

DATASET CREATION:

"OpenStreetMap is a map of the world, created by people like you and free to use under an open license."
https://www.openstreetmap.org/#map=5/38.01/-95.84

https://download.geofabrik.de/
Downloaded each of the sub-region pbfs (proprietary format used by OpenStreetMap) and ran this command:

Africa
osmium tags-filter africa-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o africa.osm.pbf
osmium export africa.osm.pbf -o africa.geojson

Antarctica
osmium tags-filter antarctica-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o antarctica.osm.pbf
osmium export antarctica.osm.pbf -o antarctica.geojson

Australia
osmium tags-filter australia-oceania-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o australia.osm.pbf
osmium export australia.osm.pbf -o australia.geojson

Asia
osmium tags-filter asia-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o asia.osm.pbf
osmium export asia.osm.pbf -o asia.geojson

Central America
osmium tags-filter central-america-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o central-america.osm.pbf
osmium export central-america.osm.pbf -o central-america.geojson

Europe
osmium tags-filter europe-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o europe.osm.pbf
osmium export europe.osm.pbf -o europe.geojson

North America
osmium tags-filter north-america-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet -o north-america.osm.pbf
osmium export north-america.osm.pbf -o north-america.geojson

South America
osmium tags-filter south-america-latest.osm.pbf n/place=village n/place=town n/place=city n/place=hamlet  -o south-america.osm.pbf
osmium export south-america.osm.pbf -o south-america.geojson


I then used the process_geojson script to reduce the information in the geojson and create a streamlined json file.
This left us with only objects marked as cities and towns with permanent residents.

IMPORTANT NOTE: The city names are normalized to standard English characters. This means we lose accents on places like Sao Paulo while storing.

These are 