# app/core/websocket.py
"""
WebSocket Manager for Real-Time Alert Notifications
====================================================
Broadcasts alerts to connected frontend dashboards immediately 
when any detection system triggers an alert.

Usage:
    from app.core.websocket import websocket_manager
    await websocket_manager.broadcast_alert(alert_payload)
"""
import json
import logging
from typing import Dict, List, Optional, Set
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)


class ConnectionManager:
    """
    Manages WebSocket connections for real-time alert broadcasting.
    Supports property-scoped connections (user only sees their own property alerts).
    """

    def __init__(self):
        # property_id -> set of active WebSocket connections
        self._property_connections: Dict[int, Set[WebSocket]] = {}
        # websocket -> property_id mapping for cleanup
        self._ws_property_map: Dict[WebSocket, int] = {}

    async def connect(self, websocket: WebSocket, property_id: int):
        """Accept connection and register for a specific property's alerts."""
        await websocket.accept()

        if property_id not in self._property_connections:
            self._property_connections[property_id] = set()

        self._property_connections[property_id].add(websocket)
        self._ws_property_map[websocket] = property_id

        logger.info(f"🔌 WebSocket connected | Property {property_id} | "
                   f"Total connections for property: {len(self._property_connections[property_id])}")

        # Send confirmation to client
        await websocket.send_json({
            "type": "connection_established",
            "property_id": property_id,
            "message": "Subscribed to real-time alerts"
        })

    def disconnect(self, websocket: WebSocket):
        """Remove connection and cleanup mappings."""
        property_id = self._ws_property_map.pop(websocket, None)

        if property_id and property_id in self._property_connections:
            self._property_connections[property_id].discard(websocket)

            # Clean up empty property sets
            if not self._property_connections[property_id]:
                del self._property_connections[property_id]

            logger.info(f"🔌 WebSocket disconnected | Property {property_id} | "
                       f"Remaining connections: {len(self._property_connections.get(property_id, set()))}")

    async def broadcast_to_property(self, property_id: int, message: dict):
        """Send message to all connected clients for a specific property."""
        if property_id not in self._property_connections:
            return

        disconnected = set()
        for websocket in self._property_connections[property_id]:
            try:
                await websocket.send_json(message)
            except Exception as e:
                logger.warning(f"Failed to send to websocket: {e}")
                disconnected.add(websocket)

        # Cleanup dead connections
        for ws in disconnected:
            self.disconnect(ws)

    async def broadcast_alert(self, alert_payload: dict):
        """
        Broadcast an alert to all connected clients monitoring the relevant property.

        Payload structure:
        {
            "type": "new_alert",
            "alert_number": int,
            "alert_type": "weapon_detection" | "unauthorized_person" | "person_climbing",
            "camera_type": "entrance" | "fence" | "insider",
            "camera_name": str,
            "camera_id": int,
            "cell_row": int | null,
            "cell_col": int | null,
            "severity": str,
            "confidence": int,
            "timestamp": str,
            "image_url": str | null,
            "message": str
        }
        """
        property_id = alert_payload.get("property_id")
        if not property_id:
            logger.error("Cannot broadcast alert: missing property_id in payload")
            return

        await self.broadcast_to_property(property_id, alert_payload)
        logger.info(f"📡 Alert broadcasted to property {property_id} | "
                   f"Type: {alert_payload.get('alert_type')} | "
                   f"Connections: {len(self._property_connections.get(property_id, set()))}")

    def get_connection_stats(self) -> dict:
        """Get current connection statistics."""
        return {
            "total_properties": len(self._property_connections),
            "total_connections": sum(len(conns) for conns in self._property_connections.values()),
            "property_breakdown": {
                prop_id: len(conns)
                for prop_id, conns in self._property_connections.items()
            }
        }


# Global singleton instance
websocket_manager = ConnectionManager()