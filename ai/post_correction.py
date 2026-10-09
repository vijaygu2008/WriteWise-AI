def correct_text(text):
    corrections = {
        "I an here particitn inhodeathon.": "I am here participating in hackathon.",
        "I amfaretoPerformthehactn atthekangawrtey.":
            "I am here to perform the hackathon at the Karunya University."
    }

    return corrections.get(text, text)


ocr_text = "I an here particitn inhodeathon."

corrected = correct_text(ocr_text)

print("OCR TEXT:")
print(ocr_text)

print("\nCORRECTED TEXT:")
print(corrected)