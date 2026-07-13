from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.dashboard import (
    DashboardResponse, ActiveAlertResponse,
    CameraFeedResponse, DroneFeedResponse,
    AlertCreateRequest, AlertResponse, AlertListResponse,
    AlertDetailResponse, GridCellSchema,
)
from app.schemas.settings import DetailResponse
from app.crud import alert as alert_crud
from app.crud import property as property_crud
from app.crud import settings as settings_crud
from app.api.v1.auth import get_current_user

router = APIRouter()


# ==================== HELPERS ====================

def format_timestamp(dt) -> str:
    if dt is None:
        return ""
    return dt.strftime("%b %d, %Y, %I:%M %p")


def alert_to_response(db_alert) -> AlertResponse:
    return AlertResponse(
        id=str(db_alert.id),
        type=db_alert.alert_type,
        camera_name=db_alert.camera_name,
        timestamp=format_timestamp(db_alert.timestamp),
        is_read=db_alert.is_read,
        confidence=db_alert.confidence,
        severity=db_alert.severity,
        image_url=db_alert.image_url,
        clip_url=db_alert.clip_url,
        camera_cell=GridCellSchema(row=db_alert.camera_cell_row, col=db_alert.camera_cell_col),
        status=db_alert.status,
        detected_cell=db_alert.detected_cell,          # ── NEW
    )


# ==================== DASHBOARD ====================

@router.get("/{property_id}", response_model=DashboardResponse)
def get_dashboard(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Get complete dashboard data for a property.
    Returns everything the PropertyDashboardScreen needs in ONE call.
    """
    # Verify property ownership
    prop = property_crud.get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    # Get cameras
    cameras = settings_crud.get_cameras(db, property_id)
    camera_feeds = [
        CameraFeedResponse(
            id=str(c.id),
            name=c.name,
            is_online=True,  # For now all cameras are "online"
            stream_url=c.rtsp_url,
            thumbnail_url=None,
        )
        for c in cameras
    ]

    # Get drones
    drones = settings_crud.get_drones(db, property_id)
    drone_feeds = [
        DroneFeedResponse(
            id=str(d.id),
            name=d.name,
            is_online=d.status in ["Ready", "Docked", "Flying"],
            stream_url=None,
        )
        for d in drones
    ]

    # Determine overall drone status
    if not drones:
        drone_status = "Offline"
    else:
        statuses = [d.status for d in drones]
        if "Flying" in statuses:
            drone_status = "Flying"
        elif "Ready" in statuses or "Docked" in statuses:
            drone_status = "Docked"
        else:
            drone_status = "Offline"

    # Get alerts
    new_alerts_count = alert_crud.get_unread_count(db, property_id)
    latest_alert = alert_crud.get_latest_active_alert(db, property_id)

    active_alert = None
    if latest_alert:
        active_alert = ActiveAlertResponse(
            id=str(latest_alert.id),
            message=f"{latest_alert.alert_type} at {latest_alert.camera_name}.",
            severity=latest_alert.severity,
            timestamp=format_timestamp(latest_alert.timestamp),
        )

    return DashboardResponse(
        success=True,
        message="Dashboard loaded",
        property_name=prop.name,
        active_alert=active_alert,
        drone_status=drone_status,
        cameras_online=len(cameras),
        cameras_total=len(cameras),
        new_alerts_count=new_alerts_count,
        cameras=camera_feeds,
        drones=drone_feeds,
        latitude=prop.latitude,
        longitude=prop.longitude,
    )


# ==================== ALERTS ====================

@router.get("/{property_id}/alerts", response_model=AlertListResponse)
def get_alerts(
    property_id: int,
    filter: str = "all",
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Get alerts for a property.
    filter: "all", "new" (unread), "active"
    """
    prop = property_crud.get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    if filter == "new":
        alerts = alert_crud.get_unread_alerts(db, property_id)
    elif filter == "active":
        alerts = alert_crud.get_active_alerts(db, property_id)
    else:
        alerts = alert_crud.get_alerts(db, property_id)

    return AlertListResponse(
        success=True,
        message=f"Found {len(alerts)} alerts",
        alerts=[alert_to_response(a) for a in alerts],
    )


@router.get("/alerts/{alert_id}", response_model=AlertDetailResponse)
def get_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get a single alert detail"""
    db_alert = alert_crud.get_alert(db, alert_id)
    if not db_alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    # Verify ownership
    prop = property_crud.get_property_for_user(db, db_alert.property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Alert not found")

    return AlertDetailResponse(
        success=True,
        message="Alert found",
        alert=alert_to_response(db_alert),
    )


@router.post("/{property_id}/alerts", response_model=AlertDetailResponse, status_code=201)
def create_alert(
    property_id: int,
    request: AlertCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Create a new alert (when camera detects something).
    This is the entry point of the surveillance flow.
    """
    prop = property_crud.get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    db_alert = alert_crud.create_alert(db, property_id, request)

    # Update property active alerts count
    prop.active_alerts = alert_crud.get_unread_count(db, property_id)
    db.commit()

    return AlertDetailResponse(
        success=True,
        message="Alert created!",
        alert=alert_to_response(db_alert),
    )


@router.put("/alerts/{alert_id}/read", response_model=DetailResponse)
def mark_alert_read(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Mark an alert as read"""
    db_alert = alert_crud.mark_as_read(db, alert_id)
    if not db_alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return DetailResponse(success=True, message="Alert marked as read")


@router.put("/alerts/{alert_id}/false-positive", response_model=DetailResponse)
def mark_false_positive(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Mark an alert as false positive (removes it from active alerts)"""
    db_alert = alert_crud.mark_as_false_positive(db, alert_id)
    if not db_alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    # Update property alert count
    prop = property_crud.get_property(db, db_alert.property_id)
    if prop:
        prop.active_alerts = alert_crud.get_unread_count(db, db_alert.property_id)
        db.commit()

    return DetailResponse(success=True, message="Alert marked as false positive")


@router.put("/alerts/{alert_id}/resolve", response_model=DetailResponse)
def resolve_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Resolve an alert"""
    db_alert = alert_crud.resolve_alert(db, alert_id)
    if not db_alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    prop = property_crud.get_property(db, db_alert.property_id)
    if prop:
        prop.active_alerts = alert_crud.get_unread_count(db, db_alert.property_id)
        db.commit()

    return DetailResponse(success=True, message="Alert resolved")


@router.delete("/alerts/{alert_id}", response_model=DetailResponse)
def delete_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Delete an alert"""
    if not alert_crud.delete_alert(db, alert_id):
        raise HTTPException(status_code=404, detail="Alert not found")
    return DetailResponse(success=True, message="Alert deleted")


# ==================== DRONE STATUS ====================

@router.put("/{property_id}/drone-status", response_model=DetailResponse)
def toggle_drone_status(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Toggle drone status between Docked and Offline"""
    prop = property_crud.get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    drones = settings_crud.get_drones(db, property_id)
    if not drones:
        raise HTTPException(status_code=400, detail="No drones configured")

    # Toggle all drones
    current_status = prop.drone_status
    new_status = "Offline" if current_status in ["Docked", "Ready"] else "Docked"

    for drone in drones:
        drone.status = new_status
    prop.drone_status = new_status
    db.commit()

    return DetailResponse(success=True, message=f"Drone status changed to {new_status}")