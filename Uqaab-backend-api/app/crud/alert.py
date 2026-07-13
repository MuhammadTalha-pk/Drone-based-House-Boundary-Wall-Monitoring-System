from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from app.models.alert import Alert
from app.schemas.dashboard import AlertCreateRequest


def get_alerts(db: Session, property_id: int, limit: int = 100) -> List[Alert]:
    return db.query(Alert).filter(
        Alert.property_id == property_id
    ).order_by(Alert.timestamp.desc()).limit(limit).all()


def get_alert(db: Session, alert_id: int) -> Optional[Alert]:
    return db.query(Alert).filter(Alert.id == alert_id).first()


def get_active_alerts(db: Session, property_id: int) -> List[Alert]:
    return db.query(Alert).filter(
        Alert.property_id == property_id,
        Alert.status == "active"
    ).order_by(Alert.timestamp.desc()).all()


def get_unread_alerts(db: Session, property_id: int) -> List[Alert]:
    return db.query(Alert).filter(
        Alert.property_id == property_id,
        Alert.is_read == False
    ).order_by(Alert.timestamp.desc()).all()


def get_unread_count(db: Session, property_id: int) -> int:
    return db.query(Alert).filter(
        Alert.property_id == property_id,
        Alert.is_read == False
    ).count()


def get_latest_active_alert(db: Session, property_id: int) -> Optional[Alert]:
    return db.query(Alert).filter(
        Alert.property_id == property_id,
        Alert.status == "active",
        Alert.is_read == False
    ).order_by(Alert.timestamp.desc()).first()


def create_alert(db: Session, property_id: int, request: AlertCreateRequest) -> Alert:
    db_alert = Alert(
        property_id=property_id,
        camera_id=request.camera_id,
        alert_type=request.alert_type,
        camera_name=request.camera_name,
        severity=request.severity,
        confidence=request.confidence,
        camera_cell_row=request.camera_cell_row,
        camera_cell_col=request.camera_cell_col,
        detected_cell_id=request.detected_cell_id,
        detected_cell_label=request.detected_cell_label,
        image_url=request.image_url,
        clip_url=request.clip_url,
    )
    db.add(db_alert)
    db.commit()
    db.refresh(db_alert)
    return db_alert


def mark_as_read(db: Session, alert_id: int) -> Optional[Alert]:
    db_alert = get_alert(db, alert_id)
    if db_alert:
        db_alert.is_read = True
        db.commit()
        db.refresh(db_alert)
    return db_alert


def mark_as_false_positive(db: Session, alert_id: int) -> Optional[Alert]:
    db_alert = get_alert(db, alert_id)
    if db_alert:
        db_alert.status = "false_positive"
        db_alert.is_read = True
        db_alert.resolved_at = datetime.utcnow()
        db.commit()
        db.refresh(db_alert)
    return db_alert


def resolve_alert(db: Session, alert_id: int) -> Optional[Alert]:
    db_alert = get_alert(db, alert_id)
    if db_alert:
        db_alert.status = "resolved"
        db_alert.is_read = True
        db_alert.resolved_at = datetime.utcnow()
        db.commit()
        db.refresh(db_alert)
    return db_alert


def delete_alert(db: Session, alert_id: int) -> bool:
    db_alert = get_alert(db, alert_id)
    if not db_alert:
        return False
    db.delete(db_alert)
    db.commit()
    return True