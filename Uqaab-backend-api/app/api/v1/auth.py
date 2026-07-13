from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, create_access_token, decode_access_token
from app.schemas.user import (
    SignupRequest,
    LoginRequest,
    AuthResponse,
    UserResponse,
    ErrorResponse,
)
from app.crud.user import get_user_by_email, get_user_by_id, create_user
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional

router = APIRouter()
security = HTTPBearer(auto_error=False)


# ======================== SIGNUP ========================
@router.post("/signup", response_model=AuthResponse)
def signup(request: SignupRequest, db: Session = Depends(get_db)):
    """
    Register a new user.

    Your Android app sends:
    {
        "full_name": "Talha",
        "email": "talha@example.com",
        "password": "123456",
        "confirm_password": "123456"
    }
    """

    # 1. Check if passwords match
    if request.password != request.confirm_password:
        raise HTTPException(
            status_code=400,
            detail="Passwords do not match"
        )

    # 2. Check if password is strong enough
    if len(request.password) < 6:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 6 characters"
        )

    # 3. Check if email already exists
    existing_user = get_user_by_email(db, request.email)
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    # 4. Create the user
    user = create_user(
        db=db,
        full_name=request.full_name,
        email=request.email,
        password=request.password,
    )

    # 5. Create token
    token = create_access_token(data={"user_id": user.id, "email": user.email})

    # 6. Return response
    return AuthResponse(
        success=True,
        message="Account created successfully!",
        user=UserResponse.model_validate(user),
        token=token,
    )


# ======================== LOGIN ========================
@router.post("/login", response_model=AuthResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    Login with email and password.

    Your Android app sends:
    {
        "email": "talha@example.com",
        "password": "123456"
    }
    """

    # 1. Find user by email
    user = get_user_by_email(db, request.email)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    # 2. Check password
    if not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    # 3. Check if active
    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Account is deactivated"
        )

    # 4. Create token
    token = create_access_token(data={"user_id": user.id, "email": user.email})

    # 5. Return response
    return AuthResponse(
        success=True,
        message="Login successful!",
        user=UserResponse.model_validate(user),
        token=token,
    )


# ======================== GET CURRENT USER ========================
def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
):
    """
    This is a dependency - it checks the token sent by the Android app
    and returns the logged-in user.
    """
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated. Please login.")

    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token. Please login again.")

    user_id = payload.get("user_id")
    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


@router.get("/me", response_model=AuthResponse)
def get_me(current_user=Depends(get_current_user)):
    """
    Get current logged-in user's profile.
    Android app sends token in header:
    Authorization: Bearer <token>
    """
    return AuthResponse(
        success=True,
        message="User profile retrieved",
        user=UserResponse.model_validate(current_user),
        token=None,
    )