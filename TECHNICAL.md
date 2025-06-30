**Tech Stack Overview**

Passport is a Flutter application that focuses on tracking and planning trips. The root README describes the project’s goal of letting users “keep track of their past trips” and share AI‑powered plans and bookings. Dependencies listed in `pubspec.yaml` show Passport uses Firebase services (authentication and Firestore), Mapbox, `photo_manager` for accessing device photos, and other Flutter packages.

The standard Flutter entry point is `lib/main.dart`. It initializes Firebase, sets up routes, and launches the application:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
runApp(MyApp());
```

Routes lead to login, signup, post‑signup, automatic trip loading, and the home screen.

---

### Login & Signup

**Login** occurs in `login_screen.dart`. The `signIn` function calls Firebase Authentication and navigates to the home screen on success:

```dart
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: emailController.text.trim(),
  password: passwordController.text.trim(),
);
Navigator.pushReplacementNamed(context, '/home');
```

**Signup** is handled in `DataSaver.signUp` within `user_data/data_operations.dart`. After a new account is created with `createUserWithEmailAndPassword`, the user document is initialized in Firestore and the app navigates to the welcome screen:

```dart
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email.trim(),
  password: password.trim(),
);
// Initialize Firestore record
await FirebaseFirestore.instance.collection('users').doc(userId).set({
  'email': email,
  'acceptedTerms': false,
});
Navigator.pushReplacementNamed(context, '/welcome');
```

---

### Post-Signup and Automatic Trip Loading

After signup, users see `PostSignUpOptionsScreen`, which allows them to manually or automatically create trips. Choosing the automatic path opens `AutomaticallyLoadTripsScreen`. Here, the `_grantPhotoAccess` method:

1. Saves selected hometowns to Firestore.
2. Fetches photos via `CustomPhotoManager.fetchPhotoMetadata`.
3. Navigates to `HomeScreen`.

```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'hometowns': hometowns,
}, SetOptions(merge: true));

await CustomPhotoManager.fetchPhotoMetadata(
  context: context,
  timeframe: timeframe,
);

Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => HomeScreen()),
);
```

`CustomPhotoManager.fetchPhotoMetadata` requests device photo permissions, reads geotagged photos, groups them into trips and stops, and saves those trips to Firestore.

---

### Home Screen & Map Handling

`HomeScreen` creates a `MapManager` instance and loads stored trips once the map is ready:

```dart
void fetchDataWhenMapIsReady() {
  if (_dataFetched) {
    print("Data already fetched, skipping re-fetch.");
    return;
  }
  _dataFetched = true;

  CustomPhotoManager.plotPhotoMetadata(
    context: context,
    mapManager: _mapManager,
  );
}
```

The `MapManager` class manages Mapbox setup, auto‑rotating the globe, plotting pins, and zooming to locations. The `plotLocationsOnMap` method loads a pin image and creates annotations for each location:

```dart
final ByteData bytes = await rootBundle.load('lib/assets/pin2.png');
final Uint8List imageData = bytes.buffer.asUint8List();
for (var loc in validLocations) {
  final annotation = PointAnnotationOptions(
    geometry: Point(coordinates: Position(loc.longitude, loc.latitude)),
    image: imageData,
    iconSize: 0.4,
  );
  await _pointAnnotationManager.create(annotation);
}
```

---

### Trip Management

Trips are displayed and edited in `MyTripsSection`. Users can create, update, merge, split, and delete trips. The logic resides in `trip_operations.dart`.

**Creating a Trip**:

```dart
final newTrip = {
  "id": UniqueKey().toString(),
  "title": title,
  "timeframe": {
    "start": timeframe.start.toIso8601String(),
    "end": timeframe.end.toIso8601String(),
  },
  "locations": locations.map((loc) => {
        "latitude": loc.latitude,
        "longitude": loc.longitude,
        "timestamp": loc.timestamp,
      }).toList(),
};
await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
```

**Editing** follows similar logic, updating the matching trip by ID.

**Merging** collects selected trips, computes combined data, and writes a new trip back to Firestore.

**Splitting** separates a trip at a given date, producing a new trip while adjusting the original timeframe.

`MyTripsSection` calls these operations through helper methods such as `_performTripMerge` and `_performTripSplit`.

---

### Data and City Lookup

The app uses city JSON datasets generated from OpenStreetMap. `lib/database/README.md` documents the process of converting OSM PBF files to GeoJSON and then to simplified JSON files for quick city lookups. The `CustomPhotoManager` and `MapManager` classes both load these datasets for mapping and nearest-city calculations.

---

### Utilities and Permissions

`photo_trip_service.dart` provides a higher-level flow to request photo access and upload photos. It uses `PermissionUtils.requestPhotoPermission` and `CustomPhotoManager.fetchPhotoMetadata` to automatically create trips, then navigates to the home screen upon success.

`PermissionUtils` encapsulates checks for photo-library permissions and can open system settings if access is denied.

---

### Current State

* The app contains working login, signup, and onboarding flows.
* Trips are generated either manually or via automatic photo scanning.
* Mapbox displays user trips with rotating-globe behavior.
* Trip editing supports merging, splitting, and deleting trips.
* City datasets are embedded for offline lookup.

---

## Concise Technical Summary

- **Frameworks & Packages**: Flutter (Dart 3), Firebase (Auth, Firestore, Storage), Mapbox Maps, `photo_manager`, `flutter_typeahead`, `provider`.
- **Architecture**: Routes defined in `main.dart` lead to login, signup, onboarding, and home. Firestore documents store user trips and photo metadata.
- **Trip Creation**: `CustomPhotoManager.fetchPhotoMetadata` loads photos, groups them by date and city, and saves trip objects to Firestore.
- **Map Display**: `MapManager` initializes Mapbox, plots pin annotations, and handles fly-to animations and globe rotation.
- **Trip Management**: CRUD operations implemented in `TripOperations` (create, edit, merge, split) and invoked from `MyTripsSection`.
- **Dataset**: Local JSON city data generated from OpenStreetMap for geolocation lookup.
- **State**: Core login and trip features exist, but some helper scripts (e.g., `test_data_operations.dart`) appear experimental.

---

## Potential Issues & Improvements

1. **Hard‑coded Mapbox token**

   The Mapbox access token is embedded in source files like `automatically_load_trips_screen.dart` and `trip_detail_view.dart`. This exposes the key and makes it difficult to rotate.

   :::task-stub{title="Move Mapbox token to secure configuration"}
   - Replace hard-coded strings in `lib/automatically_load_trips_screen.dart` and `lib/trips/trip_detail_view.dart` with a call that reads the token from an environment variable or a configuration file.
   - Document the required environment variable in `passport/README.md`.
   :::

2. **Outdated method in test script**

   `test_data_operations.dart` references `PhotoManager.fetchAllPhotoMetadata()` which does not appear in the codebase and may not exist in the `photo_manager` package.

   :::task-stub{title="Fix or remove fetchAllPhotoMetadata usage"}
   - Verify whether `photo_manager` provides `fetchAllPhotoMetadata`; if not, update the test to use available API calls (e.g., `getAssetPathList` + `getAssetListPaged`) similar to `CustomPhotoManager.fetchPhotoMetadata`.
   - Ensure the test script compiles or replace it with unit tests that call the implemented methods.
   :::

3. **Token reuse across multiple files**

   The same Mapbox token is repeated in several files, increasing maintenance burden. Centralizing configuration would avoid duplication.

   :::task-stub{title="Centralize configuration values"}
   - Create a dedicated configuration module (e.g., `lib/config.dart`) that provides constants like `mapboxAccessToken`.
   - Update all references to import this module instead of defining tokens locally.
   :::

4. **Database schema documentation**

   The `dataconnect` directory contains example GraphQL schemas unrelated to current app functions. Clarify whether these files are experimental or part of future plans.

   :::task-stub{title="Clarify or clean up dataconnect files"}
   - Confirm if `firebase/dataconnect` is necessary. If obsolete, remove it or document its purpose in a README.
   - If used, integrate the generated connectors or document how to use them.
   :::

These improvements would strengthen security and maintainability of the project.
