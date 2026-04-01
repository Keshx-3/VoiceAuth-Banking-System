# 🏦 FastAPI Banking System

A scalable, secure, and high-performance banking backend built with **FastAPI**, **SQLAlchemy**, and **Python 3.13**. This project features a robust modular architecture designed for real-world fintech applications, including atomic transactions, JWT authentication, and comprehensive audit logging.

## 🚀 Features

### **Module 1: Core Banking**
* **🔐 Secure Authentication:** JWT-based signup and login with secure password hashing (Bcrypt).
* **👤 User Management:** Profile management, avatar uploads (served statically), and contact searching.
* **💸 Atomic Transactions:** Safe money movement using atomic database transactions (ACID compliant). Supports deposits and peer-to-peer transfers with rollback safety.
* **📜 Transaction History:**
    * **Chat View:** View bidirectional transaction history with a specific contact (like a chat app).
    * **Full History:** Paginated list of all past transactions.
* **🔍 Search:** Find other users by partial name or phone number.
* **🛡️ Robust Error Handling:** Unified error responses and detailed logging with correlation IDs for traceability.

### **Module 2: AI Voice Authentication**
* **🔊 Voice Registration:** Users can register their voice by uploading multiple audio samples.
* **🧠 Deep Learning Powered:** Uses **SpeechBrain ECAPA-TDNN** to generate unique 192-dimensional voice embeddings.
* **🔐 Adaptive Security:** Calculates personalized thresholds for authentication based on sample consistency.
* **🎚️ Preprocessing:** Automatic silence trimming, volume normalization, and 3-second truncation for consistent input.
* **✅ Verification:** Authenticate users by comparing live audio against stored voice embeddings using Cosine Similarity.
* **⚡ FastAPI Ready:** Asynchronous, high-performance endpoints (`/voice/register` & `/voice/verify`) with Swagger UI docs.

### **Module 3: Fraud Detection (Coming Soon)**
* AI-driven anomaly detection for suspicious transaction patterns.

---

## 🛠️ Tech Stack

* **Framework:** [FastAPI](https://fastapi.tiangolo.com/) (High performance, easy to learn)
* **Database:** SQLite (Dev) via **SQLAlchemy ORM**
* **Migrations:** [Alembic](https://alembic.sqlalchemy.org/)
* **Validation:** [Pydantic v2](https://docs.pydantic.dev/)
* **Authentication:** OAuth2 with JWT (JSON Web Tokens)
* **Logging:** [Loguru](https://github.com/Delgan/loguru) (Structured, colorized logs)
* **Server:** [Uvicorn](https://www.uvicorn.org/) (ASGI)

---

## 📂 Project Structure

The project follows a scalable **Domain-Driven Design (DDD)** inspired structure:

```text
fastapi_bank/
├── app/
│   ├── core/                  # Configs (Security, DB, Logger, Middleware)
│   ├── models/                # SQLAlchemy Database Tables
│   ├── schemas/               # Pydantic Models (Request/Response)
│   ├── routers/               # API Endpoints (v1)
│   │   ├── auth.py            # Login/Signup
│   │   ├── users.py           # Profiles & Search
│   │   ├── transactions.py    # Deposit & Transfer Logic
│   │   └── voice_auth.py      # Voice Registration & Verification
│   └── main.py                # App Entry Point
├── alembic/                   # Database Migrations
├── static/                    # User Uploaded Files (Images)
├── logs/                      # Application Logs
├── .env                       # Environment Variables
└── requirements.txt           # Dependencies
````

-----

## ⚡ Getting Started

### 1\. Clone the Repository

```bash
git clone [https://github.com/StartUp-Challenges/FastAPI_Banking_Backend.git](https://github.com/StartUp-Challenges/FastAPI_Banking_Backend.git)
cd FastAPI_Banking_Backend
```

### 2\. Set Up Virtual Environment

```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate   # Windows
```

### 3\. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4\. Configure Environment

Create a `.env` file in the root directory:

```ini
PROJECT_NAME="FastAPI Bank"
BASE_URL="http://127.0.0.1:8000"
DATABASE_URL="sqlite:///./bank.db"
SECRET_KEY="your_super_secret_key_change_this"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
```

### 5\. Run Database Migrations

Initialize the database schema:

```bash
# Generate migration script
alembic revision --autogenerate -m "Initial migration"

# Apply changes to DB
alembic upgrade head
```

### 6\. Start the Server

```bash
uvicorn app.main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

-----

## 🧪 Testing

You can use the built-in `shell.py` to interact with your database models directly in the terminal:

```bash
ipython -i shell.py
```

```python
# Inside IPython
db.query(User).all()
```

-----

## 🤝 Contributing

Contributions are welcome\! Please fork the repository and submit a pull request for any enhancements.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request



```
```
