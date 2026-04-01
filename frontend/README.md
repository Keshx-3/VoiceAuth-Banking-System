# 🏦 Flutter Banking Frontend (GPay Clone)

A modern, responsive, and robust mobile banking application frontend inspired by Google Pay. Built with **Flutter**, prioritizing high-definition aesthetics, seamless navigation, and seamless integration with FastAPI backend architecture.

---

## 🎨 Design & Features
- **Authentic GPay Design System:** Includes exact layout clones and polished colors mirroring typical material banking interfaces.
- **Voice Authentication Engine Integration:** The frontend collects and streams micro-audio samples utilizing our speech APIs for identity verification.
- **Micro-Animations State Management:** Beautiful Lottie animations and dynamic components handling transactional flows.

---

## 🏗️ Setup & Installation

It is recommended to use an Android Emulator, iOS Simulator, or the Web Browser natively provided by the Flutter SDK to test this frontend.

### Pre-requisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version).
- Code editor like **VS Code** or **Android Studio**.

### Running the App
1. Make sure you are in the `frontend` directory.
   ```bash
   cd frontend
   ```
2. Pull all the dependencies defined in the `pubspec.yaml`.
   ```bash
   flutter pub get
   ```
3. Run the application!
   ```bash
   flutter run
   ```

*(Note: Ensure your backend is running or connected to your live API instance).*

---

## 📌 Code Structure
The `lib` code maintains a standard architectural folder structuring:
- **`lib/api_service/`**: Critical network logic that communicates with the API endpoints. Manages JSON parsing and custom Error Exceptions.
- **`lib/models/`**: Dart definitions mirroring backend schemas.
- **`lib/screens/`**: Primary application views and pages.
- **`lib/widgets/`**: Reusable user interface components.
- **`lib/services/`**: Generic helper utilities inside the platform.
