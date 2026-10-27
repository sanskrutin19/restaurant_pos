from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from backend.database.core import get_db
from backend.models.user import User
from backend.security.auth import verify_password, create_access_token, get_password_hash, ACCESS_TOKEN_EXPIRE_MINUTES, RoleChecker, get_current_user
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["Authentication"])

class Token(BaseModel):
    access_token: str
    token_type: str

class UserCreate(BaseModel):
    username: str
    password: str
    role: str

@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    print(f"[AUTH] Login attempt for user: '{form_data.username}'")
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user:
        print(f"[AUTH] Login FAILED: User '{form_data.username}' not found in database")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    is_valid = verify_password(form_data.password, user.password_hash)
    if not is_valid:
        print(f"[AUTH] Login FAILED: Invalid password provided for user '{form_data.username}'")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    print(f"[AUTH] Login SUCCESS: User '{form_data.username}' authenticated")
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "user_id": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/register", status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(RoleChecker(["admin"]))])
def register_user(user_in: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.username == user_in.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")
        
    hashed_password = get_password_hash(user_in.password)
    new_user = User(
        username=user_in.username,
        password_hash=hashed_password,
        role=user_in.role
    )
    db.add(new_user)
    db.commit()
    return {"message": "User created successfully"}

import random
import string

class ForgotPasswordRequest(BaseModel):
    username: str

class ResetPasswordRequest(BaseModel):
    username: str
    code: str
    new_password: str

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == request.username).first()
    if not user:
        # Don't reveal if user exists for security, but for this POS it's fine to be helpful
        raise HTTPException(status_code=404, detail="User not found")
    
    # Generate 6-digit numeric code
    reset_code = ''.join(random.choices(string.digits, k=6))
    user.reset_code = reset_code
    db.commit()
    
    # In a real app, send email. Here, we print to console.
    print(f"\n\n[AUTH] PASSWORD RESET CODE FOR {user.username}: {reset_code}\n\n")
    
    return {"message": "Reset code generated"}

@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == request.username).first()
    if not user or user.reset_code != request.code:
        raise HTTPException(status_code=400, detail="Invalid reset code or username")
    
    user.password_hash = get_password_hash(request.new_password)
    user.reset_code = None  # Clear the code
    db.commit()
    
    return {"message": "Password updated successfully"}

@router.post("/change-password")
async def change_password(request: ChangePasswordRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Change the password for the currently logged in user"""
    print(f"[AUTH] Change password attempt for user '{current_user.username}'")
    if not verify_password(request.current_password, current_user.password_hash):
        print(f"[AUTH] Change password failed: Current password mismatch for user '{current_user.username}'")
        raise HTTPException(status_code=400, detail="Incorrect current password")
    
    current_user.password_hash = get_password_hash(request.new_password)
    db.commit()
    print(f"[AUTH] Password changed successfully for user '{current_user.username}'")
    return {"message": "Password changed successfully"}
