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
dart pub global activate flutterfire_cli
flutterfire configure
```
- Select your Firebase project.
- The `firebase_options.dart` file will be generated in the `lib/` directory.

### **4. Start Firebase Emulator Suite**
To test authentication locally, start the Firebase Emulator Suite:
```zsh
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



