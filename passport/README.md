# Passport App

A Flutter application featuring Firebase Authentication for user login and signup, connected to the Firebase Emulator Suite for local development.

## **Features**
- User Authentication with Firebase (Signup, Login)
- Firebase Emulator Suite for local testing

---

## **Prerequisites**

### **1. Install Flutter**
- Follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install) for your operating system.
- Verify Flutter is installed:
  ```zsh
  flutter doctor
  ```

### **2. Install Firebase CLI**
- Install the Firebase CLI:
  ```zsh
  npm install -g firebase-tools
  ```
- Log in to Firebase:
  ```zsh
  firebase login
  ```
### **2a. Install FlutterFire CLI**
- Install the FlutterFire CLI globally:
  ```zsh
  dart pub global activate flutterfire_cli
  ```
- Add the Dart global binary path to your `.zshrc` if needed:
  ```zsh
  export PATH="$PATH:$HOME/.pub-cache/bin"
  ```
- Reload your terminal configuration:
  ```zsh
  source ~/.zshrc
  ```
### **2b. Create a Firebase Project**
Each teammate will need to create their own Firebase project:
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Create a new project (e.g., `passport-dev`).
3. Add the required platforms (iOS, macOS, etc.) to the project.
  
### **3. Install CocoaPods (For macOS/iOS Development)**
- Ensure CocoaPods is installed:
  ```zsh
  sudo gem install cocoapods
  ```

---

## **Setup**

### **1. Clone the Repository**
```zsh
git clone <repo_url>
cd passport
```

### **2. Install Flutter Dependencies**
```zsh
flutter pub get
```

### **3. Configure Firebase**
Run the `flutterfire configure` command to set up Firebase for your environment:
```zsh
flutterfire configure
```
- Select your Firebase project.
- The `firebase_options.dart` file will be generated in the `lib/` directory.

### **4. Add Firebase Configuration Files**
Ensure the required Firebase configuration files are present:
- **iOS**: Add `GoogleService-Info.plist` to `ios/Runner/GoogleService-Info.plist`.
- **macOS**: Add `GoogleService-Info.plist` to `macos/Runner/GoogleService-Info.plist`.

### **5. Start Firebase Emulator Suite**
To test authentication locally, start the Firebase Emulator Suite:
```zsh
cd firebase 
firebase emulators:start
```
- Authentication Emulator runs on `http://localhost:9099`.
- Emulator UI available at `http://localhost:4000`.

---

## **Running the App**

### **1. Run on iOS/Android**
```zsh
flutter run
```

---

## **Folder Structure**

```plaintext
passport/
├── lib/
│   ├── main.dart             # App entry point
│   ├── firebase_options.dart # Firebase configuration (generated)
│   ├── login_screen.dart     # Login functionality
│   ├── signup_screen.dart    # Signup functionality
│   └── home_screen.dart      # Post-login user dashboard
├── firebase.json             # Firebase emulator configuration
├── ios/                      # iOS project
├── macos/                    # macOS project
├── public/                   # Firebase hosting files (if applicable)
└── README.md                 # Project documentation
```

---


