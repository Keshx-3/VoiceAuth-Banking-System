import boto3
import os
import uuid
import shutil
from pathlib import Path
from botocore.exceptions import ClientError
from urllib.parse import urlparse
from app.core.config import settings

# Initialize S3 client only if credentials are available or implied needed
s3_client = None
if settings.AWS_ACCESS_KEY_ID and settings.AWS_SECRET_ACCESS_KEY and settings.AWS_REGION:
    s3_client = boto3.client(
        "s3",
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION,
    )

def upload_avatar(file, user_id: int) -> str:
    """
    Uploads avatar to S3 or Local storage based on configuration.
    Falls back to local storage if S3 fails.
    """
    if settings.SAVE_LOCAL:
        return save_local_avatar(file, user_id)
    
    # Try S3 if configured
    if s3_client and settings.AWS_S3_BUCKET:
        try:
            return upload_avatar_to_s3(file, user_id)
        except Exception as e:
            print(f"S3 upload failed, falling back to local storage: {e}")
            return save_local_avatar(file, user_id)
    else:
        # No S3 config, default to local
        return save_local_avatar(file, user_id)

def upload_avatar_to_s3(file, user_id: int) -> str:
    file.file.seek(0)
    file_extension = file.filename.split(".")[-1]
    key = f"avatars/user_{user_id}_{uuid.uuid4().hex}.{file_extension}"

    try:
        s3_client.upload_fileobj(
            Fileobj=file.file,
            Bucket=settings.AWS_S3_BUCKET,
            Key=key,
            ExtraArgs={"ContentType": file.content_type}
        )
    except ClientError as e:
        raise RuntimeError(f"S3 upload failed: {e}")

    return f"https://{settings.AWS_S3_BUCKET}.s3.{settings.AWS_REGION}.amazonaws.com/{key}"

def save_local_avatar(file, user_id: int) -> str:
    file.file.seek(0)
    file_extension = file.filename.split(".")[-1]
    
    # Define local path
    upload_dir = Path("media/profile_pic")
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    filename = f"user_{user_id}_{uuid.uuid4().hex}.{file_extension}"
    file_path = upload_dir / filename
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Return URL (relative or absolute based on how you serve it)
    # Assuming standard mounting at /media
    return f"{settings.BASE_URL}/media/profile_pic/{filename}"

def delete_avatar(image_url: str):
    """
    Deletes avatar from S3 or Local storage.
    """
    if not image_url:
        return

    # Check if it's a local file
    if "/media/profile_pic/" in image_url:
        delete_local_avatar(image_url)
    else:
        # Assume S3
        if s3_client and settings.AWS_S3_BUCKET:
             delete_avatar_from_s3(image_url)

def delete_avatar_from_s3(image_url: str):
    parsed = urlparse(image_url)
    key = parsed.path.lstrip("/")

    try:
        s3_client.delete_object(Bucket=settings.AWS_S3_BUCKET, Key=key)
    except ClientError as e:
        print(f"S3 delete failed: {e}")

def delete_local_avatar(image_url: str):
    try:
        # Extract filename from URL
        # URL format: http://localhost:8000/media/profile_pic/filename.ext
        filename = image_url.split("/")[-1]
        file_path = Path("media/profile_pic") / filename
        
        if file_path.exists():
            os.remove(file_path)
    except Exception as e:
        print(f"Local delete failed: {e}")
