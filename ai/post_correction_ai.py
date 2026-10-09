from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

MODEL_NAME = "vennify/t5-base-grammar-correction"

print("Loading AI correction model...")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)

print("Model loaded successfully!")

text = "I an here participating in hackathon."

input_text = "grammar: " + text

inputs = tokenizer(
    input_text,
    return_tensors="pt"
)

outputs = model.generate(
    **inputs,
    max_new_tokens=100
)

corrected_text = tokenizer.decode(
    outputs[0],
    skip_special_tokens=True
)

print("\n===== WRITEWISE AI =====")
print("Original OCR:")
print(text)

print("\nAI Corrected:")
print(corrected_text)

print("\n===== DONE =====")