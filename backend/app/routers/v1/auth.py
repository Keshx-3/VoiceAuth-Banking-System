import shutil
import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile, Header
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from loguru import logger

from app.core.database import get_db
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    get_current_user,
    oauth2_scheme
)
from app.models.user import User
from app.schemas.auth import Token, RefreshTokenRequest
from app.core.s3 import upload_avatar  # Added import

from app.models.token import TokenBlacklist
from jose import jwt, JWTError
from app.core.config import settings

router = APIRouter()

# Directory configuration (Removed IMAGEDIR as it's handled by s3.py now)

@router.post("/signup", status_code=status.HTTP_201_CREATED)
async def signup(
    phone_number: str = Form(...),
    full_name: str = Form(...),
    password: str = Form(...),
    profile_pic: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    """
    Registers a new user with a phone number, name, password, and optional profile picture.
    """
    logger.info(f"Attempting signup for {phone_number}")

    # 1. Check if user already exists (by Phone)
    if db.query(User).filter(User.phone_number == phone_number).first():
        logger.warning(f"Signup failed: Phone {phone_number} already registered")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Phone number already registered"
        )

    # 2. Validate Profile Picture (Image check only here)
    if profile_pic:
        if profile_pic.content_type not in ["image/jpeg", "image/png"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="Only .jpg and .png files allowed"
            )

    # 3. Create User with Retry Logic (For ID Collisions)
    new_user = None
    max_retries = 3
    for attempt in range(max_retries):
        try:
            # Create user first without profile pic
            new_user = User(
                phone_number=phone_number,
                full_name=full_name,
                hashed_password=get_password_hash(password),
                profile_pic=None  # Set later
            )
            
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            break # Success, exit loop
            
        except IntegrityError as e:
            db.rollback() # Rollback the failed transaction
            
            error_str = str(e)
            # Check if error is due to ID collision (Primary Key)
            if "UNIQUE constraint failed: users.id" in error_str or "users_pkey" in error_str:
                logger.warning(f"ID Collision detected. Retrying... ({attempt+1}/{max_retries})")
                continue # Retry loop
            
            # If it's a different error
            logger.error(f"Database Integrity Error: {error_str}")
            raise HTTPException(status_code=400, detail="Registration failed. Please check your details.")

    if not new_user:
         logger.error("Failed to generate unique ID after max retries")
         raise HTTPException(status_code=500, detail="System busy. Please try again.")

    # 4. Upload Profile Picture (If provided)
    if profile_pic:
        try:
            # Now we have new_user.id
            image_url = upload_avatar(profile_pic, new_user.id)
            new_user.profile_pic = image_url
            db.commit() # Save the URL
            logger.success(f"Uploaded avatar for new user {new_user.id}")
        except Exception as e:
            logger.error(f"Failed to upload avatar during signup: {e}")
            # We don't fail the whole signup, just log it. The user exists now.
            # Optionally could add a warning to response.

    logger.success(f"User {new_user.id} created successfully")
    return {"message": "User created successfully"}


@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # OAuth2 form expects 'username', we use it as 'phone_number'
    user = db.query(User).filter(User.phone_number == form_data.username).first()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        logger.warning(f"Login failed for {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid credentials"
        )
    
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    
    return {
        "access_token": access_token, 
        "refresh_token": refresh_token, 
        "token_type": "bearer"
    }

@router.post("/refresh", response_model=Token)
def refresh_access_token(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    """
    Uses a long-lived 'Refresh Token' to generate a new short-lived 'Access Token'.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # 1. Check if Refresh Token is Blacklisted
    if db.query(TokenBlacklist).filter(TokenBlacklist.token == request.refresh_token).first():
        raise HTTPException(status_code=401, detail="Refresh token has been revoked")

    # 2. Verify and Decode Token
    try:
        payload = jwt.decode(request.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # 3. Generate NEW Tokens
    # We rotate the refresh token too for extra security (optional but recommended)
    new_access_token = create_access_token(int(user_id))
    new_refresh_token = create_refresh_token(int(user_id))
    
    # 4. Optional: Blacklist the OLD refresh token so it can't be used twice
    # (This prevents 'Replay Attacks')
    old_token_blacklist = TokenBlacklist(token=request.refresh_token)
    db.add(old_token_blacklist)
    db.commit()

    return {
        "access_token": new_access_token, 
        "refresh_token": new_refresh_token, 
        "token_type": "bearer"
    }


# --- 2. LOGOUT ENDPOINT ---
@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(
    request: RefreshTokenRequest,
    token: str = Depends(oauth2_scheme),           # 1. Get the raw token string
    current_user: User = Depends(get_current_user), # 2. Validate token (This will fail if already blacklisted)
    db: Session = Depends(get_db)
):
    """
    Logs out the user by blacklisting the current Access Token and the provided Refresh Token.
    """
    
    # 3. Add Access Token to Blacklist
    # We rely on unique constraints or simple "add" logic.
    # If the token is already there, get_current_user would have blocked us.
    # But for extra safety against race conditions, we check existence.
    if not db.query(TokenBlacklist).filter(TokenBlacklist.token == token).first():
        db.add(TokenBlacklist(token=token))

    # 4. Add Refresh Token to Blacklist
    if not db.query(TokenBlacklist).filter(TokenBlacklist.token == request.refresh_token).first():
        db.add(TokenBlacklist(token=request.refresh_token))

    db.commit()
    logger.info(f"User {current_user.id} logged out successfully.")
    
    return {"message": "Successfully logged out"}