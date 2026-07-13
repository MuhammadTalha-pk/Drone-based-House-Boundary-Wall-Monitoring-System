from sqlalchemy.orm import Session
from app.models.user import User
from app.core.security import hash_password


def get_user_by_email(db: Session, email: str):
    """Find user by email"""
    return db.query(User).filter(User.email == email).first()


def get_user_by_id(db: Session, user_id: int):
    """Find user by ID"""
    return db.query(User).filter(User.id == user_id).first()


def create_user(db: Session, full_name: str, email: str, password: str):
    """Create new user with hashed password"""
    db_user = User(
        full_name=full_name,
        email=email,
        hashed_password=hash_password(password),
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user