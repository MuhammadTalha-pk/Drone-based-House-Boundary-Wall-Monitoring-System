# app/services/calibrate_wall.py
import cv2
import numpy as np
from typing import List, Dict
import json
import os


class WallCalibrator:
    def __init__(self):
        self.points: List[tuple] = []
        self.frame = None
        self.clone = None
        self.window_name = "Click 4 points on the wall (Top-Left, Top-Right, Bottom-Right, Bottom-Left)"
    
    def mouse_callback(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            if len(self.points) < 4:
                self.points.append((x, y))
                # Draw circle
                cv2.circle(self.clone, (x, y), 5, (0, 255, 0), -1)
                # Draw number
                cv2.putText(self.clone, str(len(self.points)), (x+10, y-10), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                
                # Draw polygon if we have points
                if len(self.points) > 1:
                    pts = np.array(self.points, np.int32)
                    cv2.polylines(self.clone, [pts], False, (0, 255, 255), 2)
                
                if len(self.points) == 4:
                    # Close the polygon
                    pts = np.array(self.points, np.int32)
                    cv2.polylines(self.clone, [pts], True, (0, 0, 255), 3)
                    cv2.putText(self.clone, "PRESS 'S' to SAVE, 'R' to Reset, 'Q' to Quit", 
                               (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                
                cv2.imshow(self.window_name, self.clone)
    
    def calibrate_from_rtsp(self, rtsp_url: str) -> List[Dict[str, float]]:
        """
        Open RTSP stream, grab frame 1, let user draw polygon.
        Returns: [{"x": float, "y": float}, ...] (4 points)
        """
        print(f"🔌 Connecting to: {rtsp_url}")
        cap = cv2.VideoCapture(rtsp_url)
        
        if not cap.isOpened():
            raise ValueError(f"❌ Cannot open stream: {rtsp_url}")
        
        # Grab frame 1
        ret, self.frame = cap.read()
        cap.release()
        
        if not ret:
            raise ValueError("❌ Cannot read frame from stream")
        
        print("✅ Frame captured! Click 4 points on the wall.")
        print("Order: Top-Left → Top-Right → Bottom-Right → Bottom-Left")
        
        self.clone = self.frame.copy()
        cv2.namedWindow(self.window_name)
        cv2.setMouseCallback(self.window_name, self.mouse_callback)
        cv2.imshow(self.window_name, self.clone)
        
        while True:
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('s') and len(self.points) == 4:
                break
            elif key == ord('r'):
                # Reset
                self.points = []
                self.clone = self.frame.copy()
                cv2.imshow(self.window_name, self.clone)
            elif key == ord('q'):
                self.points = []
                break
        
        cv2.destroyAllWindows()
        
        if len(self.points) != 4:
            raise ValueError("Calibration cancelled or incomplete")
        
        # Convert to JSON-serializable format
        polygon = [{"x": float(x), "y": float(y)} for x, y in self.points]
        return polygon
    
    def save_to_json(self, polygon: List[Dict], camera_id: int, output_dir: str = "fence_configs"):
        """Save as JSON backup"""
        os.makedirs(output_dir, exist_ok=True)
        filepath = os.path.join(output_dir, f"fence_config_{camera_id}.json")
        
        data = {
            "camera_id": camera_id,
            "polygon_points": polygon,
            "is_active": True
        }
        
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        
        print(f"💾 Saved to: {filepath}")
        return filepath


def point_in_polygon(point: tuple, polygon: List[Dict]) -> bool:
    """
    Ray casting algorithm to check if point is inside polygon.
    point: (x, y)
    polygon: [{"x": x1, "y": y1}, ...]
    """
    x, y = point
    n = len(polygon)
    inside = False
    
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]["x"], polygon[i]["y"]
        xj, yj = polygon[j]["x"], polygon[j]["y"]
        
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    
    return inside


# ============ STANDALONE SCRIPT ============
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python calibrate_wall.py <rtsp_url> [camera_id]")
        print("Example: python calibrate_wall.py rtsp://admin:pass@192.168.1.100:554/stream 3")
        sys.exit(1)
    
    rtsp_url = sys.argv[1]
    camera_id = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    
    calibrator = WallCalibrator()
    try:
        polygon = calibrator.calibrate_from_rtsp(rtsp_url)
        print(f"\n✅ Polygon captured: {polygon}")
        
        # Save JSON backup
        calibrator.save_to_json(polygon, camera_id)
        
        # Also print for copy-paste to API
        print(f"\n📋 Send this to POST /api/v1/cameras/{camera_id}/fence-config:")
        print(json.dumps({"points": polygon}, indent=2))
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)