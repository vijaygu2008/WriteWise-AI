import os
os.environ["FLAGS_use_mkldnn"] = "0"

from paddleocr import PaddleOCR

print("STARTING OCR...")

ocr = PaddleOCR(lang="en")

print("READING IMAGE...")

result = ocr.predict("handwriting.jpeg")

print("\n===== WRITEWISE AI RESULT =====")

for res in result:
    texts = res["rec_texts"]
    scores = res["rec_scores"]

    for text, score in zip(texts, scores):
        print(f"\nText: {text}")
        print(f"Confidence: {score:.2%}")

        if score < 0.80:
            print("UNCERTAIN - Please verify")
        else:
            print("High confidence")

print("\n===== DONE =====")
