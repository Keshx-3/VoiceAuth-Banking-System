# 🏦 Fully Featured Banking Application

A complete end-to-end banking application featuring a powerful **FastAPI Backend** and a beautiful **Flutter Frontend**. Built for demonstrating a real-world enterprise architecture, including advanced functionalities like machine learning-based Voice Authentication and robust API services.

---

## 🏗️ Repository Architecture

This repository is organized as a monorepo containing both the frontend and backend applications in their respective directories. 

```text
banking-app/
│
├── frontend/        → Flutter Framework (GPay Clone UI)
├── backend/         → FastAPI (Core Banking & ML Authentication)
├── README.md        → You are here!
└── .gitignore       → Root git ignores (augmented by folder-level ignores)
```

---

## 📱 Frontend (Flutter)

The frontend is a sleek, responsive mobile application modeled after Google Pay (GPay). It features state-of-the-art UI/UX, built natively for multiple platforms (Mobile, Web, Desktop) using Dart.

### Highlights:
- **Responsive UI:** Fully fluid and modern design.
- **Micro-Animations:** Smooth transitions and feedback on user actions.
- **API Integration:** Connects perfectly with the FastAPI Restful APIs.
- **Device Support:** Ready for Android, iOS, Windows, and browsers.

> 👉 **[Explore the Frontend Directory Setup Here](./frontend/README.md)**

---

## ⚙️ Backend (FastAPI / Server)

A scalable, secure, and blazing-fast REST API handling the core logic of the banking application, including user verification, transaction ledgers, and advanced artificial intelligence verification loops.

### Highlights:
- **Security:** Bcrypt password hashing and JWT authentication flows.
- **Voice Authentication:** Utilizes advanced SpeechBrain ECAPA-TDNN technology for generating unique biometric voice vectors. 
- **Atomic Transactions:** ACID-compliant SQLite ledger databases via SQLAlchemy migrations.
- **Live AWS Cloud:** Fully hosted and pre-configured to be consumed by the frontend.

> 👉 **[Explore the Backend API Setup Here](./backend/README.md)**

---

## 🚀 Getting Started

If you want to run this application locally, you'll need both Flutter and Python depending on what you want to test.

1. **Backend:** The backend is already deployed to AWS (`https://13.202.14.245.nip.io`). If you wish to run it locally, follow the backend README to create a virtual environment (`.venv`).
2. **Frontend:** Navigate to the `frontend` folder, run `flutter pub get` and execute `flutter run` on your preferred device.

---

*Authored and developed with ❤️.*
