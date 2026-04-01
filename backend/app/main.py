from app.core.database import Base
import app.core.logger
from app.core.middleware import LogMiddleware
from app.routers.v1 import auth, users, transactions, voice_auth, payment_requests

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.database import engine



app = FastAPI(title="FastAPI Bank")

Base.metadata.create_all(bind=engine)

# CORS MIDDLEWARE

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://fastapi-banking-backend.onrender.com",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# LOGGING MIDDLEWARE (AFTER CORS)

app.add_middleware(LogMiddleware)

# CUSTOM EXCEPTION HANDLERS

# 1. HTTP Exceptions (404, 401, etc.)
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"message": exc.detail},
    )

# 2. Validation Errors (422)
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    error_msg = exc.errors()[0].get("msg")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"message": f"Validation Error: {error_msg}"},
    )

# 3. Generic Server Errors (500)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"message": "Internal Server Error. Please try again later."},
    )

# ROUTERS & STATIC

# NOTE:
# Static mount is harmless locally.
# On Render free-tier, filesystem is ephemeral (already discussed).
import os

# Create media directory for local storage if it doesn't exist
os.makedirs("media/profile_pic", exist_ok=True)
app.mount("/media", StaticFiles(directory="media"), name="media")


# app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(transactions.router, prefix="/api/v1/transactions", tags=["Transactions"])
app.include_router(payment_requests.router, prefix="/api/v1/requests", tags=["Money Requests"])
app.include_router(voice_auth.router)

@app.get("/")
def root():
    return {"message": "Banking System is Live"}
