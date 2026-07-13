from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse, Response
from sqlalchemy.orm import Session
import cv2
import time
from pydantic import BaseModel
import numpy as np


from app.core.database import get_db
from app.crud.settings import get_camera
from app.api.v1.auth import get_current_user

router = APIRouter()


class RTSPPreviewRequest(BaseModel):
    rtsp_url: str

@router.post("/stream/preview-frame")
async def get_preview_frame(request: RTSPPreviewRequest):
    """Capture a single frame from an RTSP URL without needing a camera ID"""
    cap = None
    try:
        cap = cv2.VideoCapture(request.rtsp_url)
        
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Cannot connect to RTSP stream")
        
        # Try up to 5 frames to get a good one
        frame = None
        for _ in range(5):
            ret, f = cap.read()
            if ret and f is not None:
                frame = f
                break
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Could not capture frame from stream")
        
        # Encode to JPEG
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        
        return Response(
            content=buffer.tobytes(),
            media_type="image/jpeg"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stream error: {str(e)}")
    finally:
        if cap:
            cap.release()

# ==================== MJPEG LIVE STREAM ====================
def generate_mjpeg(rtsp_url: str):
    cap = cv2.VideoCapture(rtsp_url)

    if not cap.isOpened():
        raise Exception("Cannot open RTSP stream")

    while True:
        success, frame = cap.read()
        if not success:
            break

        ret, buffer = cv2.imencode(".jpg", frame)
        frame_bytes = buffer.tobytes()

        yield (
            b"--frame\r\n"
            b"Content-Type: image/jpeg\r\n\r\n" +
            frame_bytes +
            b"\r\n"
        )
        time.sleep(0.04)  # ~25 FPS

    cap.release()


@router.get("/{camera_id}/live")
def live_stream(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    return StreamingResponse(
        generate_mjpeg(camera.rtsp_url),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


# ==================== SINGLE FRAME (for thumbnails & calibration) ====================
@router.get("/{camera_id}/frame")
def get_camera_frame(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Returns a single JPEG frame from the camera.
    Used by:
    - CameraManagement thumbnails
    - ClimbingCalibration background image
    """
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    try:
        cap = cv2.VideoCapture(camera.rtsp_url)

        if not cap.isOpened():
            raise HTTPException(
                status_code=503,
                detail=f"Cannot connect to camera: {camera.rtsp_url}"
            )

        frame = None
        for _ in range(10):
            ret, f = cap.read()
            if ret and f is not None:
                frame = f
                break

        cap.release()

        if frame is None:
            raise HTTPException(
                status_code=503,
                detail="Could not capture frame from camera"
            )

        ret, buffer = cv2.imencode(
            '.jpg', frame,
            [cv2.IMWRITE_JPEG_QUALITY, 85]
        )

        if not ret:
            raise HTTPException(status_code=500, detail="Failed to encode frame")

        return Response(
            content=buffer.tobytes(),
            media_type="image/jpeg",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0",
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stream error: {str(e)}")

# # from fastapi import APIRouter, Depends, HTTPException, Query
# # from fastapi.responses import StreamingResponse, Response
# # from sqlalchemy.orm import Session
# # import cv2
# # import time
# # from typing import Optional

# # from app.core.database import get_db
# # from app.crud.settings import get_camera
# # from app.crud.user import get_user_by_id
# # from app.core.security import decode_access_token

# # router = APIRouter()


# # def get_user_from_token(token: Optional[str], db: Session):
# #     if not token:
# #         raise HTTPException(status_code=401, detail="Not authenticated")
# #     payload = decode_access_token(token)
# #     if not payload:
# #         raise HTTPException(status_code=401, detail="Invalid token")
# #     user_id = payload.get("user_id")
# #     user = get_user_by_id(db, user_id)
# #     if not user:
# #         raise HTTPException(status_code=401, detail="User not found")
# #     return user


# # def generate_mjpeg(rtsp_url: str):
# #     cap = cv2.VideoCapture(rtsp_url)
# #     if not cap.isOpened():
# #         raise Exception("Cannot open RTSP stream")

# #     try:
# #         while True:
# #             success, frame = cap.read()
# #             if not success:
# #                 break
# #             ret, buffer = cv2.imencode(".jpg", frame)
# #             if not ret:
# #                 continue
# #             yield (b"--frame\r\n"
# #                    b"Content-Type: image/jpeg\r\n\r\n" +
# #                    buffer.tobytes() + b"\r\n")
# #             time.sleep(0.04)
# #     finally:
# #         cap.release()


# # @router.get("/{camera_id}/live")
# # def live_stream(
# #     camera_id: int,
# #     token: Optional[str] = Query(None),
# #     db: Session = Depends(get_db),
# # ):
# #     get_user_from_token(token, db)
# #     camera = get_camera(db, camera_id)
# #     if not camera:
# #         raise HTTPException(status_code=404, detail="Camera not found")

# #     return StreamingResponse(
# #         generate_mjpeg(camera.rtsp_url),
# #         media_type="multipart/x-mixed-replace; boundary=frame"
# #     )


# # @router.get("/{camera_id}/feed")
# # def feed_stream(
# #     camera_id: int,
# #     token: Optional[str] = Query(None),
# #     db: Session = Depends(get_db),
# # ):
# #     get_user_from_token(token, db)
# #     camera = get_camera(db, camera_id)
# #     if not camera:
# #         raise HTTPException(status_code=404, detail="Camera not found")

# #     return StreamingResponse(
# #         generate_mjpeg(camera.rtsp_url),
# #         media_type="multipart/x-mixed-replace; boundary=frame"
# #     )


# # @router.get("/{camera_id}/frame")
# # def get_camera_frame(
# #     camera_id: int,
# #     token: Optional[str] = Query(None),
# #     db: Session = Depends(get_db),
# # ):
# #     get_user_from_token(token, db)
# #     camera = get_camera(db, camera_id)
# #     if not camera:
# #         raise HTTPException(status_code=404, detail="Camera not found")

# #     try:
# #         cap = cv2.VideoCapture(camera.rtsp_url)
# #         if not cap.isOpened():
# #             raise HTTPException(status_code=503, detail="Cannot connect to camera")

# #         frame = None
# #         for _ in range(10):
# #             ret, f = cap.read()
# #             if ret and f is not None:
# #                 frame = f
# #                 break
# #         cap.release()

# #         if frame is None:
# #             raise HTTPException(status_code=503, detail="Could not capture frame")

# #         ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
# #         if not ret:
# #             raise HTTPException(status_code=500, detail="Encode failed")

# #         return Response(
# #             content=buffer.tobytes(),
# #             media_type="image/jpeg",
# #             headers={
# #                 "Cache-Control": "no-cache, no-store, must-revalidate",
# #                 "Pragma": "no-cache",
# #                 "Expires": "0",
# #             }
# #         )
# #     except HTTPException:
# #         raise
# #     except Exception as e:
# #         raise HTTPException(status_code=500, detail=f"Stream error: {str(e)}")

# # app/api/v1/stream.py

# from fastapi import APIRouter, Depends, HTTPException, Path
# from fastapi.responses import StreamingResponse, Response
# from sqlalchemy.orm import Session
# import cv2
# import time

# from app.core.database import get_db
# from app.crud.settings import get_camera
# from app.api.v1.auth import get_current_user

# router = APIRouter()


# def _parse_camera_id(camera_id_str: str) -> int:
#     """
#     Convert path param to int.
#     Raises 400 (not 422) with a clear message if the value is not a valid integer.
#     This prevents the ugly 422 Unprocessable Content when the frontend
#     passes 'new' or any non-integer placeholder before the real ID is available.
#     """
#     try:
#         return int(camera_id_str)
#     except (ValueError, TypeError):
#         raise HTTPException(
#             status_code=400,
#             detail=f"Invalid camera id '{camera_id_str}'. "
#                    "Ensure the camera is saved before requesting a stream.",
#         )


# # ==================== MJPEG LIVE STREAM ====================

# def generate_mjpeg(rtsp_url: str):
#     cap = cv2.VideoCapture(rtsp_url)
#     if not cap.isOpened():
#         raise Exception("Cannot open RTSP stream")

#     while True:
#         success, frame = cap.read()
#         if not success:
#             break
#         ret, buffer = cv2.imencode(".jpg", frame)
#         frame_bytes = buffer.tobytes()
#         yield (
#             b"--frame\r\n"
#             b"Content-Type: image/jpeg\r\n\r\n" +
#             frame_bytes +
#             b"\r\n"
#         )
#         time.sleep(0.04)   # ~25 FPS

#     cap.release()


# @router.get("/{camera_id}/live")
# def live_stream(
#     camera_id: str,           # keep as str so we can give a clean error
#     db: Session = Depends(get_db),
#     current_user=Depends(get_current_user),
# ):
#     cid = _parse_camera_id(camera_id)
#     camera = get_camera(db, cid)
#     if not camera:
#         raise HTTPException(status_code=404, detail="Camera not found")

#     return StreamingResponse(
#         generate_mjpeg(camera.rtsp_url),
#         media_type="multipart/x-mixed-replace; boundary=frame",
#     )


# # ==================== SINGLE FRAME ====================

# @router.get("/{camera_id}/frame")
# def get_camera_frame(
#     camera_id: str,           # keep as str so we can give a clean error
#     db: Session = Depends(get_db),
#     current_user=Depends(get_current_user),
# ):
#     """
#     Returns a single JPEG frame from the camera.
#     Used by:
#     - CameraManagement thumbnails
#     - ClimbingCalibration / FenceCell background image
#     """
#     cid = _parse_camera_id(camera_id)
#     camera = get_camera(db, cid)
#     if not camera:
#         raise HTTPException(status_code=404, detail="Camera not found")

#     try:
#         cap = cv2.VideoCapture(camera.rtsp_url)
#         if not cap.isOpened():
#             raise HTTPException(
#                 status_code=503,
#                 detail=f"Cannot connect to camera: {camera.rtsp_url}",
#             )

#         frame = None
#         for _ in range(10):
#             ret, f = cap.read()
#             if ret and f is not None:
#                 frame = f
#                 break

#         cap.release()

#         if frame is None:
#             raise HTTPException(
#                 status_code=503,
#                 detail="Could not capture frame from camera",
#             )

#         ret, buffer = cv2.imencode(
#             ".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85]
#         )
#         if not ret:
#             raise HTTPException(status_code=500, detail="Failed to encode frame")

#         return Response(
#             content=buffer.tobytes(),
#             media_type="image/jpeg",
#             headers={
#                 "Cache-Control": "no-cache, no-store, must-revalidate",
#                 "Pragma": "no-cache",
#                 "Expires": "0",
#             },
#         )

#     except HTTPException:
#         raise
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Stream error: {str(e)}")