import os
import re

# ============================================================
# WRITEWISE AI
# Extreme Bad-Handwriting Digitization Stack
# ============================================================

os.environ["FLAGS_use_mkldnn"] = "0"

from paddleocr import PaddleOCR
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM


# ============================================================
# CONFIGURATION
# ============================================================

IMAGE_PATH = "handwriting.jpeg"
MODEL_NAME = "vennify/t5-base-grammar-correction"

OCR_UNCERTAIN_THRESHOLD = 0.80
OCR_VERY_LOW_THRESHOLD = 0.70

NUMBER_OF_CANDIDATES = 5


# ============================================================
# 1. LOAD OCR
# ============================================================

print("\n========================================")
print("       WRITEWISE AI STARTING")
print("========================================")

print("\nLoading OCR model...")

ocr = PaddleOCR(lang="en")

print("OCR model loaded!")


# ============================================================
# 2. LOAD AI MODEL
# ============================================================

print("\nLoading AI correction model...")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

model = AutoModelForSeq2SeqLM.from_pretrained(
    MODEL_NAME
)

print("AI correction model loaded!")


# ============================================================
# 3. OCR HANDWRITING
# ============================================================

print("\nReading handwriting image...")

result = ocr.predict(IMAGE_PATH)


ocr_results = []


for res in result:

    texts = res["rec_texts"]
    scores = res["rec_scores"]

    for text, score in zip(texts, scores):

        ocr_results.append({
            "text": text,
            "confidence": float(score)
        })


# ============================================================
# 4. DISPLAY OCR RESULTS
# ============================================================

print("\n========================================")
print("           OCR RESULTS")
print("========================================")


for item in ocr_results:

    text = item["text"]
    confidence = item["confidence"]

    print("\nOCR Text:")
    print(text)

    print(
        f"Confidence: {confidence:.2%}"
    )

    if confidence < OCR_UNCERTAIN_THRESHOLD:

        print(
            "STATUS: ⚠️ UNCERTAIN"
        )

    else:

        print(
            "STATUS: ✓ HIGH CONFIDENCE"
        )


# ============================================================
# 5. NORMALIZE TEXT
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
# 6. CHECK CANDIDATE SIMILARITY
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

    return (
        len(common_words) /
        len(original_words)
    )


# ============================================================
# 7. AI CANDIDATE GENERATION
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
        )

        candidate = candidate.strip()


        if candidate:

            candidates.append(candidate)


    # Remove duplicates while preserving order

    candidates = list(
        dict.fromkeys(candidates)
    )


    return candidates


# ============================================================
# 8. ANALYZE CANDIDATES
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


    # --------------------------------------------------------
    # If OCR confidence is very low
    # --------------------------------------------------------

    if confidence < OCR_VERY_LOW_THRESHOLD:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": candidates
        }


    # --------------------------------------------------------
    # Remove candidates with extremely different
    # word structure
    # --------------------------------------------------------

    valid_candidates = []


    original_word_count = len(
        original.split()
    )


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


    # --------------------------------------------------------
    # Calculate agreement between candidates
    # --------------------------------------------------------

    overlaps = []


    for candidate in valid_candidates:

        overlap = word_overlap(
            original,
            candidate
        )

        overlaps.append(
            overlap
        )


    best_index = overlaps.index(
        max(overlaps)
    )


    best_candidate = valid_candidates[
        best_index
    ]


    best_overlap = overlaps[
        best_index
    ]


    # --------------------------------------------------------
    # Candidate agreement
    # --------------------------------------------------------

    unique_candidates = list(
        dict.fromkeys(valid_candidates)
    )


    # Multiple substantially different
    # interpretations = uncertain

    if len(unique_candidates) >= 3:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": unique_candidates
        }


    # --------------------------------------------------------
    # Require reasonable overlap
    # --------------------------------------------------------

    if best_overlap < 0.50:

        return {
            "status": "UNCERTAIN",
            "final_text": original,
            "candidates": unique_candidates
        }


    # --------------------------------------------------------
    # Otherwise accept candidate
    # --------------------------------------------------------

    return {
        "status": "ACCEPTED",
        "final_text": best_candidate,
        "candidates": unique_candidates
    }


# ============================================================
# 9. PROCESS EACH OCR REGION
# ============================================================

print("\n========================================")
print("        AI CANDIDATE ANALYSIS")
print("========================================")


final_results = []


for index, item in enumerate(
    ocr_results,
    start=1
):

    original = item["text"]
    confidence = item["confidence"]


    print("\n----------------------------------------")

    print(
        f"REGION {index}"
    )

    print("----------------------------------------")


    print("\nOriginal OCR:")

    print(original)


    print(
        f"\nOCR Confidence: "
        f"{confidence:.2%}"
    )


    # --------------------------------------------------------
    # Generate candidates
    # --------------------------------------------------------

    candidates = generate_candidates(
        original
    )


    print("\nAI Candidates:")


    for number, candidate in enumerate(
        candidates,
        start=1
    ):

        print(
            f"{number}. {candidate}"
        )


    # --------------------------------------------------------
    # Analyze
    # --------------------------------------------------------

    analysis = analyze_candidates(

        original,

        candidates,

        confidence
    )


    status = analysis["status"]

    final_text = analysis["final_text"]


    # --------------------------------------------------------
    # Final decision
    # --------------------------------------------------------

    if status == "ACCEPTED":

        print(
            "\nSTATUS: ✓ CORRECTION ACCEPTED"
        )

        print(
            "\nFinal Text:"
        )

        print(final_text)


    else:

        print(
            "\nSTATUS: ⚠️ UNCERTAIN"
        )

        print(
            "\nFinal Text:"
        )

        print(original)

        print(
            "\n⚠️ HUMAN VERIFICATION REQUIRED"
        )


    final_results.append({

        "original": original,

        "confidence": confidence,

        "candidates": candidates,

        "status": status,

        "final_text": final_text
    })


# ============================================================
# 10. FINAL DIGITIZED TEXT
# ============================================================

print("\n========================================")
print("         FINAL DIGITIZED TEXT")
print("========================================")


for item in final_results:

    print(
        "\n" + item["final_text"]
    )


# ============================================================
# 11. PIPELINE COMPLETE
# ============================================================

print("\n========================================")
print("       WRITEWISE AI PIPELINE COMPLETE")
print("========================================")