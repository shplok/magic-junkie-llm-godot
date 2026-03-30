"""
Finetuning Script for Dialogue Model
Run this in Google Colab with GPU enabled (Runtime > Change runtime type > T4 GPU)

Steps:
1. Upload your dialogue_training.jsonl to Colab
2. Run this script
3. Download the generated .gguf file
4. Place in your Godot project's models/ folder
"""

# Install dependencies (run once)
# !pip install -q "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
# !pip install -q --no-deps xformers trl peft accelerate bitsandbytes

from unsloth import FastLanguageModel
import torch
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset

# ==================== CONFIGURATION ====================
MODEL_NAME = "Qwen/Qwen2.5-1.5B-Instruct"  # Base model
DATASET_FILE = "dialogue_training.jsonl"    # Your training data
OUTPUT_NAME = "my_dialogue_model"           # Output model name
MAX_SEQ_LENGTH = 512                        # Max context length
EPOCHS = 3                                  # Training epochs
BATCH_SIZE = 2                              # Adjust based on GPU memory
# =======================================================

print("🚀 Starting finetuning process...")

# 1. Load model
print(f"📥 Loading base model: {MODEL_NAME}")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = MODEL_NAME,
    max_seq_length = MAX_SEQ_LENGTH,
    dtype = None,
    load_in_4bit = True,
)

# 2. Add LoRA adapters
print("🔧 Adding LoRA adapters...")
model = FastLanguageModel.get_peft_model(
    model,
    r = 16,
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj",
                      "gate_proj", "up_proj", "down_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
    use_gradient_checkpointing = "unsloth",
    random_state = 3407,
)

# 3. Load dataset
print(f"📚 Loading training data from {DATASET_FILE}")
dataset = load_dataset("json", data_files=DATASET_FILE, split="train")
print(f"   Found {len(dataset)} training examples")

# 4. Format conversations
def formatting_prompts_func(examples):
    convos = examples["messages"]
    texts = [tokenizer.apply_chat_template(convo, tokenize=False, add_generation_prompt=False)
             for convo in convos]
    return {"text": texts}

dataset = dataset.map(formatting_prompts_func, batched=True)

# 5. Train
print(f"🏋️ Training for {EPOCHS} epochs...")
trainer = SFTTrainer(
    model = model,
    tokenizer = tokenizer,
    train_dataset = dataset,
    dataset_text_field = "text",
    max_seq_length = MAX_SEQ_LENGTH,
    dataset_num_proc = 2,
    packing = False,
    args = TrainingArguments(
        per_device_train_batch_size = BATCH_SIZE,
        gradient_accumulation_steps = 4,
        warmup_steps = 5,
        num_train_epochs = EPOCHS,
        learning_rate = 2e-4,
        fp16 = not torch.cuda.is_bf16_supported(),
        bf16 = torch.cuda.is_bf16_supported(),
        logging_steps = 1,
        optim = "adamw_8bit",
        weight_decay = 0.01,
        lr_scheduler_type = "linear",
        seed = 3407,
        output_dir = "outputs",
        report_to = "none",
    ),
)

trainer.train()

# 6. Test the model
print("\n🧪 Testing model...")
FastLanguageModel.for_inference(model)

test_messages = [{"role": "user", "content": "Hello, who are you?"}]
inputs = tokenizer.apply_chat_template(
    test_messages,
    tokenize=True,
    add_generation_prompt=True,
    return_tensors="pt"
).to("cuda")

print("\nTest output:")
outputs = model.generate(inputs, max_new_tokens=64, temperature=0.7)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))

# 7. Save as GGUF (ready for Godot!)
print(f"\n💾 Saving as GGUF: {OUTPUT_NAME}-q4.gguf")
model.save_pretrained_gguf(OUTPUT_NAME, tokenizer, quantization_method="q4_k_m")

print("\n✅ Done! Download the .gguf file and place it in your Godot models/ folder")
print(f"   File: {OUTPUT_NAME}/unsloth.Q4_K_M.gguf")
