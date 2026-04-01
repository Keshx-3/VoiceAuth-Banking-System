from datetime import datetime, timedelta
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User
from app.models.token import TokenBlacklist

pwd_context = CryptContext(
    schemes=["argon2"], 
    deprecated="auto",
    # This ensures passlib handles the backend correctly and suppresses the 72-byte error
    bcrypt__rounds=12
)

def create_token(data: dict, expires_delta: timedelta):
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_access_token(user_id: int):
    # Convert int ID to string for the token subject
    to_encode = {"sub": str(user_id)}
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_refresh_token(user_id: int):
    to_encode = {"sub": str(user_id)}
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

# This tells FastAPI that the token comes from the "/login" endpoint
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 1. CHECK BLACKLIST FIRST
    # If the token is found in the blacklist table, reject it immediately.
    is_blacklisted = db.query(TokenBlacklist).filter(TokenBlacklist.token == token).first()
    if is_blacklisted:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked (Logged out)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 2. Decode Token
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # 3. Get User from DB
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
        
    return user