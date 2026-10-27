from datetime import datetime, timedelta
from typing import Optional, List
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.models.user import User

# In a real app, load this from environment variables
SECRET_KEY = "super-secret-local-pos-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 12 # 12 hour shift

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

from fastapi import Depends, HTTPException, status, Query

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token", auto_error=False)

async def get_current_user(
    token_header: Optional[str] = Depends(oauth2_scheme),
    token_query: Optional[str] = Query(None, alias="token"),
    db: Session = Depends(get_db)
):
    token = token_header or token_query
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    if not token:
        raise credentials_exception
        
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise credentials_exception
    return user

async def get_current_user_optional(
    token_header: Optional[str] = Depends(oauth2_scheme),
    token_query: Optional[str] = Query(None, alias="token"),
    db: Session = Depends(get_db)
):
    token = token_header or token_query
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            return None
        return db.query(User).filter(User.username == username).first()
    except JWTError:
        return None

class RoleChecker:
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: User = Depends(get_current_user)):
        role_lower = (user.role or "").lower()
        allowed_lower = [r.lower() for r in self.allowed_roles]
        
        # Super admin always has access
        if role_lower == "super_admin" or role_lower == "admin":
            return user
            
        if role_lower not in allowed_lower:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action"
            )
        return user

class PermissionChecker:
    def __init__(self, permission_key: str):
        self.permission_key = permission_key

    def __call__(self, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
        from backend.models.user import Role
        
        # 1. Admin bypass
        if (user.role or "").lower() == "admin":
            return user
            
        # 2. Check user-specific overrides
        if user.permissions and user.permissions.get(self.permission_key) is not None:
            if user.permissions[self.permission_key]:
                return user
            else:
                raise HTTPException(status_code=403, detail=f"Permission denied: {self.permission_key}")

        # 3. Check Role template
        role_template = db.query(Role).filter(Role.name == user.role).first()
        if role_template and role_template.permissions:
            if role_template.permissions.get(self.permission_key):
                return user
        
        raise HTTPException(status_code=403, detail=f"Permission denied: {self.permission_key}")
