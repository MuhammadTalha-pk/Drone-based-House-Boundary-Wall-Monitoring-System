# app/services/face_recognition_service.py
"""
Face Recognition Service
========================
Compares a detected face encoding against all authorized persons
for a given property.

Returns True  (authorized) + person details   → no alert
Returns False (unauthorized)                  → caller must trigger alert
"""
import logging
import numpy as np
from typing import Optional, Tuple, List
from sqlalchemy.orm import Session

from app.models.authorized_person import AuthorizedPerson

logger = logging.getLogger(__name__)

# Tune this: lower = stricter match.  0.5 works well with face_recognition lib.
RECOGNITION_THRESHOLD = 0.50


class FaceRecognitionResult:
    """Returned by FaceRecognitionService.recognize()"""

    def __init__(
        self,
        is_authorized: bool,
        person_id: Optional[int] = None,
        person_name: Optional[str] = None,
        role: Optional[str] = None,
        confidence: float = 0.0,
    ):
        self.is_authorized  = is_authorized
        self.person_id      = person_id
        self.person_name    = person_name
        self.role           = role
        self.confidence     = confidence   # 0-1, higher = more similar

    def __repr__(self):
        if self.is_authorized:
            return (
                f"<FaceRecognitionResult authorized=True "
                f"person='{self.person_name}' role='{self.role}' conf={self.confidence:.3f}>"
            )
        return f"<FaceRecognitionResult authorized=False conf={self.confidence:.3f}>"


class FaceRecognitionService:
    """
    Matches a 128-d face encoding against authorized_persons.face_encodings.

    Usage:
        svc    = FaceRecognitionService(db)
        result = svc.recognize(property_id=1, face_encoding=encoding)
        if result.is_authorized:
            ...  # do nothing
        else:
            ...  # trigger alert
    """

    def __init__(self, db: Session):
        self.db = db

    # ─────────────────────────────────────────────────────────────
    # PUBLIC API
    # ─────────────────────────────────────────────────────────────
    def recognize(
        self,
        property_id: int,
        face_encoding: List[float],
    ) -> FaceRecognitionResult:
        """
        Match face_encoding against all authorized persons for the property.

        Returns:
            FaceRecognitionResult with is_authorized=True/False
        """
        if not face_encoding:
            logger.warning("recognize() called with empty encoding → unauthorized")
            return FaceRecognitionResult(is_authorized=False)

        query_vec = np.array(face_encoding, dtype=np.float64)

        # Load all authorized persons for this property that have stored encodings
        persons: List[AuthorizedPerson] = (
            self.db.query(AuthorizedPerson)
            .filter(
                AuthorizedPerson.property_id == property_id,
                AuthorizedPerson.face_encodings.isnot(None),
            )
            .all()
        )

        if not persons:
            logger.debug(f"No authorized persons with encodings for property {property_id}")
            return FaceRecognitionResult(is_authorized=False)

        best_distance = float("inf")
        best_person: Optional[AuthorizedPerson] = None

        for person in persons:
            stored_encodings: List[List[float]] = person.face_encodings or []
            if not stored_encodings:
                continue

            # A person may have multiple photos → multiple encodings; take closest
            for enc in stored_encodings:
                try:
                    candidate_vec = np.array(enc, dtype=np.float64)
                    if candidate_vec.shape != query_vec.shape:
                        continue

                    distance = float(np.linalg.norm(query_vec - candidate_vec))

                    if distance < best_distance:
                        best_distance = distance
                        best_person   = person
                except Exception as e:
                    logger.error(f"Encoding comparison failed for person {person.id}: {e}")
                    continue

        if best_person is not None and best_distance < RECOGNITION_THRESHOLD:
            # Convert distance to a 0-1 "confidence" (1 = perfect match)
            confidence = max(0.0, 1.0 - (best_distance / RECOGNITION_THRESHOLD))

            logger.info(
                f"✅ AUTHORIZED: person_id={best_person.id} "
                f"name='{best_person.name}' role='{best_person.role}' "
                f"distance={best_distance:.4f} conf={confidence:.3f}"
            )
            return FaceRecognitionResult(
                is_authorized=True,
                person_id=best_person.id,
                person_name=best_person.name,
                role=best_person.role,
                confidence=confidence,
            )

        logger.info(
            f"❌ UNAUTHORIZED: best_distance={best_distance:.4f} "
            f"threshold={RECOGNITION_THRESHOLD}"
        )
        return FaceRecognitionResult(
            is_authorized=False,
            confidence=max(0.0, 1.0 - (best_distance / RECOGNITION_THRESHOLD))
            if best_distance < float("inf")
            else 0.0,
        )

    # ─────────────────────────────────────────────────────────────
    # HELPER — encode a single face crop (used by detect_face_service)
    # ─────────────────────────────────────────────────────────────
    @staticmethod
    def compute_encoding(face_crop_bgr) -> Optional[List[float]]:
        """
        Given a BGR numpy array (face crop), return a 128-d face_recognition
        encoding or None if no face is found.
        """
        try:
            import face_recognition  # pip install face_recognition
            import cv2

            rgb = cv2.cvtColor(face_crop_bgr, cv2.COLOR_BGR2RGB)
            encodings = face_recognition.face_encodings(rgb)

            if not encodings:
                return None

            return encodings[0].tolist()   # list of 128 floats
        except Exception as e:
            logger.error(f"compute_encoding failed: {e}")
            return None

    @staticmethod
    def encode_all_photos_for_person(photo_paths: List[str]) -> List[List[float]]:
        """
        Utility: encode several photos for a person during registration.
        Call this when adding/updating an authorized person.
        Returns a list of 128-d encodings (one per successfully encoded photo).
        """
        import face_recognition
        import cv2

        encodings = []
        for path in photo_paths:
            try:
                img = cv2.imread(path)
                if img is None:
                    continue
                rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                enc_list = face_recognition.face_encodings(rgb)
                if enc_list:
                    encodings.append(enc_list[0].tolist())
            except Exception as e:
                logger.error(f"Failed to encode {path}: {e}")
        return encodings

# """
# Face Recognition Service
# =========================
# Compares a detected face encoding against all authorized persons
# for a given property.

# Returns True  (authorized) + person details   → no alert
# Returns False (unauthorized)                  → caller must trigger alert

# ENCODING: Uses dlib 128-d face embeddings via face_recognition library.
# THRESHOLD: 0.6 is the standard dlib threshold for Euclidean distance.
#            lower = stricter (more false unauthorized)
#            higher = looser  (more false authorized)
# """
# import logging
# import numpy as np
# import cv2
# from typing import Optional, Tuple, List
# from sqlalchemy.orm import Session

# from app.models.authorized_person import AuthorizedPerson

# logger = logging.getLogger(__name__)

# # ─────────────────────────────────────────────────────────────
# # CONFIG
# # ─────────────────────────────────────────────────────────────
# # dlib/face_recognition standard: same person ≈ 0.0–0.6, different ≈ 0.6–1.2
# RECOGNITION_THRESHOLD = 0.60   # ✅ Corrected from 0.50

# # Minimum face crop size for reliable dlib encoding
# MIN_FACE_SIZE_PX = 80


# class FaceRecognitionResult:
#     """Returned by FaceRecognitionService.recognize()"""

#     def __init__(
#         self,
#         is_authorized: bool,
#         person_id: Optional[int] = None,
#         person_name: Optional[str] = None,
#         role: Optional[str] = None,
#         confidence: float = 0.0,
#         distance: float = float("inf"),
#     ):
#         self.is_authorized = is_authorized
#         self.person_id     = person_id
#         self.person_name   = person_name
#         self.role          = role
#         self.confidence    = confidence   # 0–1, higher = more similar
#         self.distance      = distance     # raw Euclidean distance (for debugging)

#     def __repr__(self):
#         if self.is_authorized:
#             return (
#                 f"<FaceRecognitionResult authorized=True "
#                 f"person='{self.person_name}' role='{self.role}' "
#                 f"dist={self.distance:.3f} conf={self.confidence:.3f}>"
#             )
#         return (
#             f"<FaceRecognitionResult authorized=False "
#             f"dist={self.distance:.3f} conf={self.confidence:.3f}>"
#         )


# class FaceRecognitionService:
#     """
#     Matches a 128-d face encoding against authorized_persons.face_encodings.

#     Usage:
#         svc    = FaceRecognitionService(db)
#         result = svc.recognize(property_id=1, face_encoding=encoding)
#         if result.is_authorized:
#             ...  # known person, no alert
#         else:
#             ...  # unknown person, trigger alert
#     """

#     def __init__(self, db: Session):
#         self.db = db

#     # ─────────────────────────────────────────────────────────────
#     # PUBLIC API
#     # ─────────────────────────────────────────────────────────────
#     def recognize(
#         self,
#         property_id: int,
#         face_encoding: List[float],
#     ) -> FaceRecognitionResult:
#         """
#         Match face_encoding against all authorized persons for the property.

#         Returns:
#             FaceRecognitionResult with is_authorized=True/False
#         """
#         if not face_encoding:
#             logger.warning("recognize() called with empty encoding → unauthorized")
#             return FaceRecognitionResult(is_authorized=False)

#         query_vec = np.array(face_encoding, dtype=np.float64)

#         if query_vec.shape != (128,):
#             logger.warning(
#                 f"Unexpected encoding shape {query_vec.shape} "
#                 f"(expected (128,)) → unauthorized"
#             )
#             return FaceRecognitionResult(is_authorized=False)

#         # Load all authorized persons for this property that have stored encodings
#         persons: List[AuthorizedPerson] = (
#             self.db.query(AuthorizedPerson)
#             .filter(
#                 AuthorizedPerson.property_id == property_id,
#                 AuthorizedPerson.face_encodings.isnot(None),
#             )
#             .all()
#         )

#         if not persons:
#             logger.debug(
#                 f"No authorized persons with encodings for property {property_id}"
#             )
#             return FaceRecognitionResult(is_authorized=False)

#         best_distance = float("inf")
#         best_person: Optional[AuthorizedPerson] = None

#         for person in persons:
#             stored_encodings: List[List[float]] = person.face_encodings or []
#             if not stored_encodings:
#                 continue

#             # A person may have multiple photos → multiple encodings; take closest
#             for enc in stored_encodings:
#                 try:
#                     candidate_vec = np.array(enc, dtype=np.float64)

#                     if candidate_vec.shape != (128,):
#                         logger.warning(
#                             f"Skipping malformed encoding for person "
#                             f"{person.id} — shape {candidate_vec.shape}"
#                         )
#                         continue

#                     distance = float(np.linalg.norm(query_vec - candidate_vec))

#                     if distance < best_distance:
#                         best_distance = distance
#                         best_person   = person

#                 except Exception as e:
#                     logger.error(
#                         f"Encoding comparison failed for person {person.id}: {e}"
#                     )
#                     continue

#         # ── Decision ──────────────────────────────────────────────
#         if best_person is not None and best_distance < RECOGNITION_THRESHOLD:
#             confidence = max(0.0, 1.0 - (best_distance / RECOGNITION_THRESHOLD))

#             logger.info(
#                 f"✅ AUTHORIZED: person_id={best_person.id} "
#                 f"name='{best_person.name}' role='{best_person.role}' "
#                 f"distance={best_distance:.4f} conf={confidence:.3f}"
#             )
#             return FaceRecognitionResult(
#                 is_authorized=True,
#                 person_id=best_person.id,
#                 person_name=best_person.name,
#                 role=best_person.role,
#                 confidence=confidence,
#                 distance=best_distance,
#             )

#         logger.info(
#             f"❌ UNAUTHORIZED: best_distance={best_distance:.4f} "
#             f"threshold={RECOGNITION_THRESHOLD} "
#             f"best_candidate={best_person.id if best_person else 'none'}"
#         )
#         return FaceRecognitionResult(
#             is_authorized=False,
#             distance=best_distance,
#             confidence=max(0.0, 1.0 - (best_distance / RECOGNITION_THRESHOLD))
#             if best_distance < float("inf")
#             else 0.0,
#         )

#     # ─────────────────────────────────────────────────────────────
#     # STATIC: encode a single face crop
#     # ─────────────────────────────────────────────────────────────
#     @staticmethod
#     def compute_encoding(face_crop_bgr) -> Optional[List[float]]:
#         """
#         Given a BGR numpy array (face crop from detector), return a 128-d
#         dlib face encoding or None if encoding fails.

#         Key fix: we tell face_recognition the face location is the full image,
#         so dlib skips re-detection (which fails on tight crops) and encodes
#         directly.
#         """
#         try:
#             import face_recognition

#             if face_crop_bgr is None:
#                 return None

#             h, w = face_crop_bgr.shape[:2]

#             # ✅ Reject crops too small for reliable encoding
#             if h < MIN_FACE_SIZE_PX or w < MIN_FACE_SIZE_PX:
#                 logger.debug(
#                     f"Face crop too small ({w}x{h}) "
#                     f"< {MIN_FACE_SIZE_PX}px → skipping encoding"
#                 )
#                 return None

#             rgb = cv2.cvtColor(face_crop_bgr, cv2.COLOR_BGR2RGB)

#             # ✅ Critical fix: pass known_face_locations so dlib skips
#             # internal HOG detection (which fails on pre-cropped faces).
#             # Location format: (top, right, bottom, left) in pixels.
#             face_location = [(0, w, h, 0)]

#             encodings = face_recognition.face_encodings(
#                 rgb,
#                 known_face_locations=face_location,
#                 num_jitters=1,       # 1 = fast; increase to 3-5 for accuracy
#                 model="small",       # "small" (5-point) or "large" (68-point landmarks)
#             )

#             if not encodings:
#                 logger.debug("face_recognition returned no encodings for crop")
#                 return None

#             encoding = encodings[0]

#             # Sanity check: dlib always returns exactly 128 floats
#             if len(encoding) != 128:
#                 logger.warning(f"Unexpected encoding length: {len(encoding)}")
#                 return None

#             return encoding.tolist()

#         except Exception as e:
#             logger.error(f"compute_encoding failed: {e}", exc_info=True)
#             return None

#     # ─────────────────────────────────────────────────────────────
#     # STATIC: encode multiple photos (used during person registration)
#     # ─────────────────────────────────────────────────────────────
#     @staticmethod
#     def encode_all_photos_for_person(photo_paths: List[str]) -> List[List[float]]:
#         """
#         Encode several photos for a person during registration.
#         Call this when adding/updating an authorized person.

#         Returns a list of 128-d encodings (one per successfully encoded photo).
#         Uses standard face_encodings() (full image) — correct for registration photos.
#         """
#         import face_recognition

#         encodings = []
#         for path in photo_paths:
#             try:
#                 img = cv2.imread(path)
#                 if img is None:
#                     logger.warning(f"Could not read image: {path}")
#                     continue

#                 h, w = img.shape[:2]
#                 if h < MIN_FACE_SIZE_PX or w < MIN_FACE_SIZE_PX:
#                     logger.warning(
#                         f"Image too small ({w}x{h}) for reliable encoding: {path}"
#                     )
#                     continue

#                 rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

#                 # For registration photos (full image): let dlib detect face first
#                 enc_list = face_recognition.face_encodings(
#                     rgb,
#                     num_jitters=3,    # More jitters = more accurate (slower)
#                     model="large",    # 68-point landmarks = more accurate
#                 )

#                 if enc_list:
#                     encodings.append(enc_list[0].tolist())
#                     logger.info(f"✅ Encoded: {path}")
#                 else:
#                     logger.warning(f"No face found in: {path}")

#             except Exception as e:
#                 logger.error(f"Failed to encode {path}: {e}")

#         logger.info(
#             f"Encoded {len(encodings)}/{len(photo_paths)} photos successfully"
#         )
#         return encodings