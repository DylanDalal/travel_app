/// A simple data class for geotagged photos or user locations.
class Location {
  final double latitude;
  final double longitude;
  final String timestamp;
  final String? closestCity; // Add this field

  Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.closestCity,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'closestCity': closestCity,
    };
  }
}

class City {
  final String name;
  final double latitude;
  final double longitude;

  City({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}