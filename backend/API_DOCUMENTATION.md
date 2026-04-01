# API Documentation - FastAPI Banking Backend

This document provides a comprehensive guide for frontend developers to integrate with the banking backend.

## 🔑 Authentication

All protected endpoints require a Bearer Token in the `Authorization` header.

**Header Format:**
```
Authorization: Bearer <your_access_token>
```

---

## 🛡️ Authentication Endpoints (`/api/v1/auth`)

### 1. Signup
- **URL**: `/api/v1/auth/signup`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Parameters**:
  - `phone_number` (string, required)
  - `full_name` (string, required)
  - `password` (string, required)
  - `profile_pic` (file, optional)
- **Response**: `{"message": "User created successfully"}`

### 2. Login
- **URL**: `/api/v1/auth/login`
- **Method**: `POST`
- **Content-Type**: `application/x-www-form-urlencoded`
- **Parameters**:
  - `username` (string, required) - *Use the phone number here*
  - `password` (string, required)
- **Response**:
  ```json
  {
    "access_token": "...",
    "refresh_token": "...",
    "token_type": "bearer"
  }
  ```

### 3. Refresh Token
- **URL**: `/api/v1/auth/refresh`
- **Method**: `POST`
- **Body**: `{"refresh_token": "..."}`
- **Response**: New access and refresh tokens.

### 4. Logout
- **URL**: `/api/v1/auth/logout`
- **Method**: `POST`
- **Body**: `{"refresh_token": "..."}`
- **Auth**: Required
- **Description**: Revokes both the current access token and the provided refresh token.

---

## 👤 User Endpoints (`/api/v1/users`)

### 1. Get Profile
- **URL**: `/api/v1/users/me`
- **Method**: `GET`
- **Auth**: Required
- **Response**:
  ```json
  {
    "id": 123,
    "phone_number": "99...",
    "full_name": "John Doe",
    "balance": 1000.0,
    "profile_pic": "url_to_image"
  }
  ```

### 2. Update Avatar
- **URL**: `/api/v1/users/me/avatar`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Auth**: Required
- **Parameters**: `profile_pic` (file)

### 3. Get Recent Contacts
- **URL**: `/api/v1/users/contacts`
- **Method**: `GET`
- **Auth**: Required
- **Description**: Returns unique users you have transacted with.

### 4. Search Users
- **URL**: `/api/v1/users/search`
- **Method**: `GET`
- **Auth**: Required
- **Query Params**: `query` (string) - Search by name or phone.

---

## 💸 Transaction Endpoints (`/api/v1/transactions`)

### 1. Deposit Money
- **URL**: `/api/v1/transactions/deposit`
- **Method**: `POST`
- **Auth**: Required
- **Body**: `{"amount": 500}`

### 2. Transfer Money
- **URL**: `/api/v1/transactions/transfer`
- **Method**: `POST`
- **Auth**: Required
- **Body**: `{"amount": 100, "receiver_phone": "99..."}`
- **Logic**: Checks balance, runs fraud detection, and updates both accounts.

### 3. Chat History (Interaction Flow)
- **URL**: `/api/v1/transactions/chat/{contact_id}`
- **Method**: `GET`
- **Auth**: Required
- **Description**: Returns all interactions (Transfers, Received, and Payment Requests) between you and a specific user.
- **Labels in Response**:
  - `transaction_type`: "TRANSFER", "RECEIVED", or "REQUEST".
  - `status`: "SUCCESS", "PENDING", "REJECTED", etc.

### 4. Transaction History
- **URL**: `/api/v1/transactions/history`
- **Method**: `GET`
- **Auth**: Required
- **Query Params**: `skip` (int), `limit` (int)
- **Description**: Lists all global transactions for the user.

---

## 📩 Payment Requests (`/api/v1/requests`)

### 1. Create Request
- **URL**: `/api/v1/requests/`
- **Method**: `POST`
- **Auth**: Required
- **Body**: `{"amount": 500, "payer_phone": "99..."}`

### 2. List My Requests
- **URL**: `/api/v1/requests/`
- **Method**: `GET`
- **Auth**: Required
- **Description**: Returns requests you sent or received.

### 3. Respond to Request
- **URL**: `/api/v1/requests/{request_id}/{action}`
- **Method**: `POST`
- **Auth**: Required
- **Path Params**:
  - `request_id`: ID of the request.
  - `action`: `ACCEPT` or `REJECT`.
- **Logic**: Accepting a request triggers an automatic transfer.

---

## 🎙️ Voice Authentication (`/voice`)

### 1. Register Voice
- **URL**: `/voice/register`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Auth**: Required
- **Parameters**: `audio_files` (List of files, at least 2 samples)

### 2. Verify Voice
- **URL**: `/voice/verify`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Auth**: Required
- **Parameters**: `audio` (Single audio file)
- **Response**:
  ```json
  {
    "similarity": 0.95,
    "authenticated": true
  }
  ```

---

## 🛡️ Fraud Engine & Security
- **Fraud Detection**: Every transfer and request is analyzed by an ML model. If flagged, the status will be `FLAGGED`.
- **Risk Blocking**: Receivers with too many flagged transactions may be temporarily blocked from receiving more funds.
- **ID Collision Protection**: The system automatically retries user/transaction creation if a random ID collision occurs.
