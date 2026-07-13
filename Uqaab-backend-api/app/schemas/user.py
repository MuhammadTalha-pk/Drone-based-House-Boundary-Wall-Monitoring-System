from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# ========== What Android App SENDS to Backend ==========

class SignupRequest(BaseModel):
    """
    Matches your Android signup form:
    - signupFullName
    - signupEmail
    - signupPassword
    """
    full_name: str
    email: EmailStr
    password: str
    confirm_password: str


class LoginRequest(BaseModel):
    """
    Matches your Android login form:
    - loginEmail
    - loginPassword
    """
    email: EmailStr
    password: str


# ========== What Backend SENDS back to Android App ==========

class UserResponse(BaseModel):
    """User data sent back to the app"""
    id: int
    full_name: str
    email: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """
    Response after login/signup.
    Android app will store the token.
    """
    success: bool
    message: str
    user: Optional[UserResponse] = None
    token: Optional[str] = None


class ErrorResponse(BaseModel):
    """Error response"""
    success: bool = False
    message: str