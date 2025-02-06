import json
from shapely.geometry import shape
import ijson
from tqdm import tqdm
from decimal import Decimal

def decimal_default(obj):
    """Convert Decimal objects to float for JSON serialization."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")

def process_geojson(input_file, output_file):
    cities = []
    min_pop = 10000
    max_pop = 0
    with open(input_file, 'r') as f:
        try: # look i got lazy with all of the use cases ok?
            for feature in tqdm(ijson.items(f, 'features.item')):
                try:
                    properties = feature.get('properties', {})
                    geometry = feature.get('geometry', {})

                    # Extract city name and coordinates
                    city_name = properties.get('name', 'Unknown')
                    # Extract city name and coordinates
                    population = int(properties.get('population', 0))

                    # Skip if the name is "Unknown"
                    if city_name == "Unknown" or population == 0:
                        continue

                    lat, lon = None, None

                    if geometry.get('type') == 'Point':
                        lon, lat = geometry['coordinates']
                    elif geometry.get('type') in ['Polygon', 'MultiPolygon']:
                        bounds = shape(geometry).bounds  # Get bounding box
                        lon = (bounds[0] + bounds[2]) / 2  # Approximate centroid longitude
                        lat = (bounds[1] + bounds[3]) / 2  # Approximate centroid latitude

                    cities.append({
                        'name': city_name,
                        'latitude': lat,
                        'longitude': lon,
                    })
                    print(f"{city_name}: {population}")
                    if population > max_pop:
                        max_pop = population
                    elif population < min_pop:
                        min_pop = population
                except Exception as e:
                    print(f"Skipping invalid feature: {e}")

        except ijson.common.IncompleteJSONError as e:
            print(f"Error reading JSON: {e}")
        except Exception as e:
            print(f"Unexpected error: {e}")

    # Save to compact JSON, handling Decimal conversion
    try:
        with open(output_file, 'w') as f:
            json.dump(cities, f, indent=2, default=decimal_default)
    except Exception as e:
        print(f"Error writing JSON: {e}")

    print(min_pop)
    print(max_pop)

# Process city nodes or boundaries
process_geojson('cities_towns_villages.geojson', 'cities_towns_villages.json')
