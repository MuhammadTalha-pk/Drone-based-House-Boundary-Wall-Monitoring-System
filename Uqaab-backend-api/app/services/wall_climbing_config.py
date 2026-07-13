# app/services/wall_climbing_config.py
"""
Tuning guide for detection sensitivity.

PROBLEM: Too many false positives (person walking near wall triggers alert)
SOLUTION: Increase min_points_inside and min_confidence

PROBLEM: Missing real intruders (person on wall not detected)  
SOLUTION: Decrease min_points_inside or min_confidence

YOLOv8 Pose keypoints (17 total):
    0: nose
    1: left_eye,    2: right_eye
    3: left_ear,    4: right_ear
    5: left_shoulder, 6: right_shoulder
    7: left_elbow,  8: right_elbow
    9: left_wrist,  10: right_wrist
    11: left_hip,   12: right_hip
    13: left_knee,  14: right_knee
    15: left_ankle, 16: right_ankle

For WALL CLIMBING specifically:
- Climber on wall → torso + arms inside polygon
- Person walking past → only 1-2 keypoints near edge

Recommended settings by scenario:
"""

DETECTION_CONFIG = {
    # Person must be mostly inside zone
    "strict": {
        "min_points_inside": 7,   # More than half body in zone
        "min_confidence": 0.6,    # High confidence keypoints only
        "model_conf": 0.6,        # High confidence detections only
        "frame_skip": 3,          # Process every 3rd frame
    },
    
    # Balanced (recommended)
    "balanced": {
        "min_points_inside": 5,   # About 1/3 of body in zone
        "min_confidence": 0.5,
        "model_conf": 0.5,
        "frame_skip": 3,
    },
    
    # Catch everything (more false positives)
    "sensitive": {
        "min_points_inside": 3,   # Any 3 keypoints in zone
        "min_confidence": 0.3,
        "model_conf": 0.4,
        "frame_skip": 2,
    },
}

# Use this config
ACTIVE_CONFIG = DETECTION_CONFIG["balanced"]