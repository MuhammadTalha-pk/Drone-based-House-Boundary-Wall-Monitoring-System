# app/api/v1/websocket.py
"""
WebSocket Endpoint for Real-Time Alert Subscriptions
======================================================
Frontend dashboard connects here to receive instant alert notifications.

Connection URL:
    ws://your-backend.com/api/v1/ws/alerts/{property_id}?token=<jwt_token>

Example JavaScript (frontend):
    const ws = new WebSocket('ws://localhost:8000/api/v1/ws/alerts/1?token=eyJhbG...');
    ws.onmessage = (event) => {
        const alert = JSON.parse(event.data);
        if (alert.type === 'new_alert') {
            showNotification(alert);
        }
    };
"""
from networkx.readwrite import json_graph
from networkx.readwrite import json_graph
from networkx.readwrite import json_graph
from networkx.readwrite import json_graph
from PIL.Image import logger
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Optional

from app.core.websocket import websocket_manager
from app.core.database import get_db
from app.core.security import decode_access_token
from app.crud.property import get_property_for_user

router = APIRouter()


async def get_user_from_token(token: str, db: Session):
    """Validate JWT token and return user."""
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    from app.crud.user import get_user_by_id
    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


@router.websocket("/alerts/{property_id}")
async def websocket_alerts(
    websocket: WebSocket,
    property_id: int,
    token: str = Query(..., description="JWT access token"),
    db: Session = Depends(get_db),
):
    """
    WebSocket endpoint for real-time alert notifications.

    - Validates JWT token from query parameter
    - Verifies user owns the property
    - Maintains persistent connection for alert push notifications
    - Auto-disconnects on token expiry or property access loss

    Query Parameters:
        token: JWT access token from login/signup response
    """
    try:
        # Validate user
        user = await get_user_from_token(token, db)

        # Verify property ownership
        prop = get_property_for_user(db, property_id, user.id)
        if not prop:
            await websocket.close(code=4004, reason="Property not found or access denied")
            return

        # Register connection
        await websocket_manager.connect(websocket, property_id)

        # Keep connection alive and handle client messages
        while True:
            try:
                # Wait for client messages (ping/heartbeat or ack)
                data = await websocket.receive_text()
                message = json.loads(data)

                msg_type = message.get("type", "")

                if msg_type == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": message.get("timestamp")})

                elif msg_type == "ack_alert":
                    # Client acknowledged receiving an alert
                    alert_id = message.get("alert_id")
                    logger.info(f"Alert {alert_id} acknowledged by user {user.id}")

                elif msg_type == "get_stats":
                    # Client requests connection stats
                    stats = websocket_manager.get_connection_stats()
                    await websocket.send_json({"type": "stats", "data": stats})

            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON"})

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for property {property_id}")

    except Exception as e:
        logger.error(f"WebSocket error for property {property_id}: {e}")

    finally:
        websocket_manager.disconnect(websocket)