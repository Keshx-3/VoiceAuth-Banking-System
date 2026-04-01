import shutil
import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.orm import Session
from loguru import logger

from app.schemas.user import UserResponse, UserContact
from app.models.transaction import Transaction
from app.models.user import User
from app.core.s3 import upload_avatar as upload_avatar_file, delete_avatar
from app.core.security import get_current_user
from app.core.database import get_db
from sqlalchemy import or_

router = APIRouter()

@router.get("/me", response_model=UserResponse)
def get_my_profile(current_user: User = Depends(get_current_user)):
    """
    Fetch the current logged-in user's profile and balance.
    """
    return current_user

@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    profile_pic: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Validate file type
    if profile_pic.content_type not in ["image/jpeg", "image/png"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only .jpg and .png files allowed"
        )

    if current_user.profile_pic:
        delete_avatar(current_user.profile_pic)

    # 3. Upload new avatar (S3 or Local with fallback)
    try:
        image_url = upload_avatar_file(profile_pic, current_user.id)
    except Exception as e:
        logger.error(f"Upload failed: {e}")
        raise HTTPException(
            status_code=500,
            detail="Could not upload image"
        )

    # 4. Update DB
    current_user.profile_pic = image_url
    db.commit()
    db.refresh(current_user)

    logger.success(f"Updated avatar for user {current_user.id}")

    return current_user

@router.get("/contacts", response_model=list[UserContact])
def get_recent_contacts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Returns a list of unique users involved in transactions with you.
    (People you sent money to OR people who sent money to you)
    """
    # 1. Query all transactions involving the current user
    # logic: (sender == me) OR (receiver == me)
    transactions = db.query(Transaction).filter(
        or_(
            Transaction.sender_id == current_user.id,
            Transaction.receiver_id == current_user.id
        )
    ).order_by(Transaction.timestamp.desc()).all()

    # 2. Extract unique contacts
    contacts_map = {} # Using a dict to ensure uniqueness by ID
    
    for txn in transactions:
        other_user = None
        
        # If I am the sender, the "contact" is the receiver
        if txn.sender_id == current_user.id:
            other_user = txn.receiver
            
        # If I am the receiver, the "contact" is the sender
        elif txn.receiver_id == current_user.id:
            other_user = txn.sender
            
        # Add to map if not added yet (and ensure it's not None, e.g. system deposit)
        if other_user and other_user.id not in contacts_map:
            contacts_map[other_user.id] = other_user

    # 3. Return as a list
    return list(contacts_map.values())

@router.get("/search", response_model=list[UserContact])
def search_users(
    query: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Search for users by Phone Number OR Full Name.
    Case-insensitive partial match (icontains).
    Excludes the current user from results.
    """
    if not query:
        return []

    # ILIKE is Postgres specific. For SQLite, standard LIKE is case-insensitive usually,
    # but strictly speaking, we use python's ".ilike" method in SQLAlchemy which handles it.
    users = db.query(User).filter(
        or_(
            User.full_name.ilike(f"%{query}%"),
            User.phone_number.ilike(f"%{query}%")
        )
    ).filter(
        User.id != current_user.id # Exclude self
    ).limit(20).all() # Limit results to prevent massive lists

    return users

@router.get("/me/voice-auth", response_model=bool)
def get_voice_auth_status(current_user: User = Depends(get_current_user)):
    """
    Returns the current status of voice authentication for the logged-in user.
    """
    return current_user.use_voice_auth

@router.post("/me/voice-auth", response_model=bool)
def toggle_voice_auth(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Toggles the voice authentication status for the logged-in user.
    """
    current_user.use_voice_auth = not current_user.use_voice_auth
    db.commit()
    db.refresh(current_user)
    return current_user.use_voice_auth
