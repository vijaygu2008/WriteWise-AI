from transformers import AutoTokenizer, AutoModelForSeq2SeqLM


# ============================================================
# WRITEWISE AI - CANDIDATE CORRECTION TEST
# ============================================================

MODEL_NAME = "vennify/t5-base-grammar-correction"

print("Loading AI model...")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)

print("AI model loaded!")


# ============================================================
# OCR TEXT
# ============================================================

ocr_text = "I an here particitn inhodeathon."

print("\nOriginal OCR:")
print(ocr_text)


# ============================================================
# GENERATE MULTIPLE CANDIDATES
# ============================================================

input_text = "grammar: " + ocr_text

inputs = tokenizer(
    input_text,
    return_tensors="pt"
)


outputs = model.generate(
    **inputs,
    max_new_tokens=100,
    num_beams=5,
    num_return_sequences=5,
    early_stopping=True
)


# ============================================================
# DISPLAY CANDIDATES
# ============================================================

print("\n===== AI CANDIDATES =====")

candidates = []

for i, output in enumerate(outputs):

    text = tokenizer.decode(
        output,
        skip_special_tokens=True
    )

    candidates.append(text)

    print(f"\nCandidate {i + 1}:")
    print(text)


# ============================================================
# SIMPLE DECISION
# ============================================================

print("\n===== CANDIDATE ANALYSIS =====")

unique_candidates = list(
    dict.fromkeys(candidates)
)

if len(unique_candidates) == 1:

    print("Strong agreement between AI candidates.")
    print("Suggested correction:")
    print(unique_candidates[0])

else:

    print("AI produced multiple possible corrections.")
    print("⚠️ HUMAN VERIFICATION REQUIRED")

    print("\nPossible corrections:")

    for candidate in unique_candidates:

        print("-", candidate)


print("\n===== DONE =====")