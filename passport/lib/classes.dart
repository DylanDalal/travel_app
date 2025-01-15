/// A simple data class for geotagged photos or user locations.
class Location {
  final double latitude;
  final double longitude;
  final String timestamp;

  /// Creates a new [Location] with the given latitude, longitude, and timestamp.
  const Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
