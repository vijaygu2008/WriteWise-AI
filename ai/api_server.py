import os
import re
import shutil
import tempfile

os.environ["FLAGS_use_mkldnn"] = "0"

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from paddleocr import PaddleOCR
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM


# ============================================================
# WRITEWISE AI API
# ============================================================

app = FastAPI(
    title="WriteWise AI API",
    version="1.0.0"
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# SETTINGS
# ============================================================

MODEL_NAME = "vennify/t5-base-grammar-correction"

OCR_UNCERTAIN_THRESHOLD = 0.80
OCR_VERY_LOW_THRESHOLD = 0.70

NUMBER_OF_CANDIDATES = 5


# ============================================================
# LOAD OCR
# ============================================================

print("\nLoading PaddleOCR...")

ocr = PaddleOCR(
    lang="en"
)

print("PaddleOCR loaded!")


# ============================================================
# LOAD AI CORRECTION MODEL
# ============================================================

print("\nLoading AI correction model...")

tokenizer = AutoTokenizer.from_pretrained(
    MODEL_NAME
)

model = AutoModelForSeq2SeqLM.from_pretrained(
    MODEL_NAME
)

print("AI correction model loaded!")


# ============================================================
# HOME / HEALTH CHECK
# ============================================================

@app.get("/")
def home():

    return {
        "status": "online",
        "app": "WriteWise AI",
        "message": "Handwriting digitization API is running"
    }


# ============================================================
# TEXT NORMALIZATION
# ============================================================

def normalize_text(text):

    text = text.lower()

    text = re.sub(
        r"[^a-z0-9\s]",
        "",
        text
    )

    text = re.sub(
        r"\s+",
        " ",
        text
    )

    return text.strip()


# ============================================================
# WORD OVERLAP
# ============================================================

def word_overlap(original, candidate):

    original_words = set(
        normalize_text(original).split()
    )

    candidate_words = set(
        normalize_text(candidate).split()
    )

    if not original_words:
        return 0.0

    common_words = (
        original_words &
        candidate_words
    )

    return len(common_words) / len(original_words)


# ============================================================
# GENERATE AI CANDIDATES
# ============================================================

def generate_candidates(text):

    input_text = "grammar: " + text

    inputs = tokenizer(
        input_text,
        return_tensors="pt"
    )

    outputs = model.generate(

        **inputs,

        max_new_tokens=100,

        num_beams=5,

        num_return_sequences=NUMBER_OF_CANDIDATES,

        early_stopping=True
    )

    candidates = []

    for output in outputs:

        candidate = tokenizer.decode(
            output,
            skip_special_tokens=True
        ).strip()

        if candidate:
            candidates.append(candidate)

    # Remove duplicates
    candidates = list(
        dict.fromkeys(candidates)
    )

    return candidates


# ============================================================
# ANALYZE AI CANDIDATES
# ============================================================

def analyze_candidates(
    original,
    candidates,
    confidence
):

    if not candidates:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": []
        }


    # Very low OCR confidence
    if confidence < OCR_VERY_LOW_THRESHOLD:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": candidates
        }


    original_word_count = len(
        original.split()
    )


    valid_candidates = []


    # Check candidate length
    for candidate in candidates:

        candidate_word_count = len(
            candidate.split()
        )

        difference = abs(
            candidate_word_count -
            original_word_count
        )

        if difference <= max(
            2,
            original_word_count
        ):

            valid_candidates.append(
                candidate
            )


    if not valid_candidates:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": candidates
        }


    # Score candidates
    scored_candidates = []


    for candidate in valid_candidates:

        overlap = word_overlap(
            original,
            candidate
        )

        scored_candidates.append(
            (
                candidate,
                overlap
            )
        )


    scored_candidates.sort(
        key=lambda item: item[1],
        reverse=True
    )


    best_candidate = (
        scored_candidates[0][0]
    )

    best_overlap = (
        scored_candidates[0][1]
    )


    unique_candidates = list(
        dict.fromkeys(
            valid_candidates
        )
    )


    # Multiple interpretations
    if len(unique_candidates) >= 3:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": unique_candidates
        }


    # Poor similarity
    if best_overlap < 0.50:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": unique_candidates
        }


    return {
        "status": "ACCEPTED",
        "final_text": best_candidate,
        "candidates": unique_candidates
    }


# ============================================================
# EXTRACT OCR BOX
# ============================================================

def extract_box(res, index):

    try:

        # PaddleOCR 3.x
        boxes = res["rec_polys"]

        box = boxes[index]

        points = []

        for point in box:

            points.append([
                int(point[0]),
                int(point[1])
            ])

        return points

    except Exception:

        try:

            boxes = res["rec_boxes"]

            box = boxes[index]

            x1 = int(box[0])
            y1 = int(box[1])
            x2 = int(box[2])
            y2 = int(box[3])

            return [
                [x1, y1],
                [x2, y1],
                [x2, y2],
                [x1, y2]
            ]

        except Exception:

            return []


# ============================================================
# ANALYZE HANDWRITING
# ============================================================

@app.post("/analyze")
async def analyze_handwriting(
    file: UploadFile = File(...)
):

    temp_path = None


    try:

        # ----------------------------------------------------
        # Save uploaded image
        # ----------------------------------------------------

        suffix = os.path.splitext(
            file.filename or ".jpg"
        )[1]


        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix
        ) as temp_file:

            temp_path = temp_file.name

            shutil.copyfileobj(
                file.file,
                temp_file
            )


        print(
            f"\nAnalyzing image: {file.filename}"
        )


        # ----------------------------------------------------
        # OCR
        # ----------------------------------------------------

        result = ocr.predict(
            temp_path
        )


        regions = []


        # ----------------------------------------------------
        # Process OCR regions
        # ----------------------------------------------------

        for res in result:

            texts = res["rec_texts"]

            scores = res["rec_scores"]


            for index, (text, score) in enumerate(
                zip(texts, scores)
            ):

                text = str(text)

                confidence = float(score)


                # --------------------------------------------
                # Bounding box
                # --------------------------------------------

                box = extract_box(
                    res,
                    index
                )


                # --------------------------------------------
                # AI candidate generation
                # --------------------------------------------

                candidates = generate_candidates(
                    text
                )


                # --------------------------------------------
                # Safety analysis
                # --------------------------------------------

                analysis = analyze_candidates(

                    text,

                    candidates,

                    confidence
                )


                # --------------------------------------------
                # Determine uncertainty
                # --------------------------------------------

                is_uncertain = (

                    confidence <
                    OCR_UNCERTAIN_THRESHOLD

                    or

                    analysis["status"] ==
                    "UNCERTAIN"
                )


                # --------------------------------------------
                # Severity
                # --------------------------------------------

                if confidence < OCR_VERY_LOW_THRESHOLD:

                    uncertainty_level = "HIGH"

                elif is_uncertain:

                    uncertainty_level = "MEDIUM"

                else:

                    uncertainty_level = "LOW"


                # --------------------------------------------
                # Region
                # --------------------------------------------

                regions.append({

                    "region_id":
                        len(regions) + 1,

                    "ocr_text":
                        text,

                    "confidence":
                        round(
                            confidence,
                            4
                        ),

                    "confidence_percent":
                        round(
                            confidence * 100,
                            2
                        ),

                    "status":
                        analysis["status"],

                    "uncertain":
                        is_uncertain,

                    "uncertainty_level":
                        uncertainty_level,

                    "final_text":
                        analysis["final_text"],

                    "candidates":
                        analysis["candidates"],

                    "box":
                        box
                })


        # ----------------------------------------------------
        # Final digitized text
        # ----------------------------------------------------

        final_text_parts = []


        for region in regions:

            final_text_parts.append(
                region["final_text"]
            )


        final_text = "\n".join(
            final_text_parts
        )


        # ----------------------------------------------------
        # Overall uncertainty
        # ----------------------------------------------------

        has_uncertainty = any(

            region["uncertain"]

            for region in regions
        )


        # ----------------------------------------------------
        # Response
        # ----------------------------------------------------

        return {

            "success": True,

            "filename":
                file.filename,

            "final_text":
                final_text,

            "uncertain":
                has_uncertainty,

            "region_count":
                len(regions),

            "regions":
                regions
        }


    except Exception as error:

        print(
            "ERROR:",
            str(error)
        )


        return {

            "success": False,

            "error":
                str(error)
        }


    finally:

        # ----------------------------------------------------
        # Delete temporary image
        # ----------------------------------------------------

        if (
            temp_path
            and
            os.path.exists(temp_path)
        ):

            os.remove(
                temp_path
            )


# ============================================================
# SERVER INFORMATION
# ============================================================

print("\n========================================")
print("       WRITEWISE AI API READY")
print("========================================")
print("Endpoint: POST /analyze")
print("Health:   GET  /")
print("Bounding boxes: ENABLED")
print("Uncertainty detection: ENABLED")
print("========================================\n")