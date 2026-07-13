# app/services/wall_climbing_debug.py
"""
Run this standalone to see what the detector sees in real-time.
Helps verify polygon placement and sensitivity tuning.

Usage:
    python -m app.services.wall_climbing_debug <camera_id>
"""
import cv2
import sys
import numpy as np
from app.core.database import SessionLocal
from app.models.camera import Camera
from app.models.fence_config import FenceConfig
from app.services.wall_climbing import (
    person_in_polygon,
    draw_polygon_overlay,
    draw_person_annotations,
    denormalize_polygon,
)


def debug_camera(camera_id: int):
    """Show live detection visualization with polygon overlay."""
    db = SessionLocal()
    
    try:
        camera = db.query(Camera).filter(Camera.id == camera_id).first()
        if not camera:
            print(f"Camera {camera_id} not found")
            return
            
        config = db.query(FenceConfig).filter(
            FenceConfig.camera_id == camera_id
        ).first()
        
        if not config:
            print(f"No fence config for camera {camera_id}")
            return
            
        polygon = config.polygon_points
        rtsp_url = camera.rtsp_url
        
    finally:
        db.close()
    
    print(f"Opening: {rtsp_url}")
    print(f"Polygon: {polygon}")
    print("Press 'q' to quit")
    print("GREEN box = person detected but NOT in zone")
    print("RED box   = INTRUDER detected in zone")
    print("CYAN dots = keypoints with confidence > 0.5")
    print("RED dots  = keypoints INSIDE the polygon zone")
    
    from ultralytics import YOLO
    model = YOLO("yolov8n-pose.pt")
    
    cap = cv2.VideoCapture(rtsp_url)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    
    if not cap.isOpened():
        print("Cannot open stream!")
        return
    
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Stream lost")
            break
        
        frame_count += 1
        if frame_count % 3 != 0:
            continue
        
        h, w = frame.shape[:2]
        display = frame.copy()
        
        # Draw polygon
        display = draw_polygon_overlay(display, polygon, is_alert=False)
        
        # Run detection
        results = model(frame, verbose=False, conf=0.4)
        result = results[0]
        
        intruder_found = False
        
        if (result.keypoints is not None 
                and result.boxes is not None
                and len(result.boxes) > 0):
            
            boxes = result.boxes.xyxy.cpu().numpy()
            box_confs = result.boxes.conf.cpu().numpy()
            keypoints_all = result.keypoints.data.cpu().numpy()
            
            for box, box_conf, keypoints in zip(
                boxes, box_confs, keypoints_all
            ):
                is_intruder, pts_inside, inside_coords = person_in_polygon(
                    keypoints=keypoints,
                    polygon=polygon,
                    frame_w=w,
                    frame_h=h,
                    min_points_inside=5,
                    min_confidence=0.5,
                )
                
                if is_intruder:
                    intruder_found = True
                
                display = draw_person_annotations(
                    display, box, keypoints,
                    is_intruder, inside_coords, pts_inside
                )
                
                # Show keypoint count on screen
                x1 = int(box[0])
                y1 = int(box[1])
                cv2.putText(
                    display,
                    f"kp_in={pts_inside} conf={box_conf:.2f}",
                    (x1, y1 - 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                    (255, 255, 0), 1
                )
        
        if intruder_found:
            display = draw_polygon_overlay(display, polygon, is_alert=True)
        
        # Status bar
        status = "INTRUDER IN ZONE" if intruder_found else "Zone Clear"
        status_color = (0, 0, 255) if intruder_found else (0, 200, 0)
        cv2.putText(
            display, status,
            (10, h - 20),
            cv2.FONT_HERSHEY_SIMPLEX, 0.8,
            status_color, 2
        )
        
        cv2.imshow(f"Debug - Camera {camera_id}", display)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    cam_id = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    debug_camera(cam_id)