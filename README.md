# 🏦 Next-Gen Banking App: AI-Powered Voice Authentication

A full-stack, state-of-the-art banking ecosystem featuring a **Flutter (GPay Clone)** frontend and a high-performance **FastAPI** backend. This project was engineered to directly address the 2026 RBI mandate requiring strict 2FA via real-time biometric Voice Authentication (replacing legacy OTP systems).

![Voice Auth POC](https://img.shields.io/badge/Voice%20Authentication-ECAPA--TDNN-blue?style=for-the-badge)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi)
![Flutter](https://img.shields.io/badge/Flutter-Frontend-02569B?style=for-the-badge&logo=flutter)
![Deployed](https://img.shields.io/badge/Deployed-AWS-FF9900?style=for-the-badge&logo=amazon-aws)

---

## 🚨 The Catalyst: Transitioning Away from "OTP-Only"
> *As of April 1, 2026, the RBI mandated 2FA for all digital payments due to escalating phishing and SIM-swap scams. Following global precedents (like UAE's Face-Auth), this Proof of Concept demonstrates how zero-friction conversational biometrics can serve as the ultimate transaction layer.*

This ecosystem allows users to securely verify transactions natively via Voice Print extraction—making the experience highly resistant to fraud.

---

## 🏗️ Monorepo Architecture

This project is organized into two primary segments natively contained in this repository:

```text
banking-app/
│
├── frontend/        → Flutter Framework (GPay Clone UI)
└── backend/         → FastAPI (Core Banking & ML Voice Engine)
```

---

## 📱 1. Frontend (Flutter)

A sleek, responsive mobile application modeled after Google Pay (GPay). Created exclusively for a seamless UX ensuring frictionless biometric enrollments and payments.

### Highlights:
- **Responsive UI:** Fully fluid and modern design tailored for Android, iOS, and Web.
- **Micro-Animations State Management:** Custom Lottie animations during verification flows and data loading states.
- **Voice Engine Hookup:** Real-time capture of `.wav` micro-audio samples interacting directly with backend inference APIs.
- **Architecture:** Clean `lib/api_service/` network routing, coupled with dynamic exception handling for suspended accounts.

### Frontend Setup:
```bash
cd frontend
flutter pub get
flutter run
```

---

## ⚙️ 2. Backend (FastAPI / Server)

A scalable REST API designed entirely using Domain-Driven Design (DDD). It manages the atomic transaction ledger and functions as the biometric inference brain.

### Highlights:
- **🧠 AI Voice Engine:** Utilizes **SpeechBrain ECAPA-TDNN** to extract 192-dimensional voice embeddings for precise cosine similarity verification.
- **🔐 Secure Authentication:** Bcrypt password hashing and OAuth2 JWT flows.
- **💸 Atomic Transactions:** Safe money movement utilizing ACID-compliant SQLAlchemy migrations preventing race conditions.
- **📜 Live Ledger:** Full paginated history with bidirectional, chat-style transaction views.
- **Live AWS Cloud:** Fully hosted and pre-configured for instant frontend pairing.

### Architecture
<img width="2048" height="315" alt="image" src="https://github.com/user-attachments/assets/2d8eb88b-ce45-48dc-b052-c4549fa58ab4" />


### Backend Setup:
The backend logic operates locally on port 8000 via SQLite if detached from AWS. 
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # (or .venv\Scripts\activate on Windows)
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

---

## 🌐 Tech Stack Details
- **Frontend Layer:** Flutter (Dart), Lottie, Google Fonts.
- **Backend Framework:** FastAPI, Uvicorn, Python 3.13.
- **Database Model:** SQLite / PostgreSQL, SQLAlchemy ORM, Alembic Migrations.
- **Machine Learning Layer:** PyTorch, SpeechBrain.

---
*Developed with a focus on FinTech Security and Scalable Enterprise Delivery.*
