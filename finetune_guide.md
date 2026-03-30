# Finetuning Guide for Dialogue Models

## Quick Start with Unsloth (Recommended)

### Installation
```bash
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
pip install --no-deps xformers trl peft accelerate bitsandbytes
```

### Training Script

```python
from unsloth import FastLanguageModel
import torch
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset

# 1. Load base model
max_seq_length = 512
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "Qwen/Qwen2.5-1.5B-Instruct",
    max_seq_length = max_seq_length,
    dtype = None,  # Auto-detect
    load_in_4bit = True,  # Use 4-bit for memory efficiency
)

# 2. Add LoRA adapters (efficient finetuning)
model = FastLanguageModel.get_peft_model(
    model,
    r = 16,  # LoRA rank
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj",
                      "gate_proj", "up_proj", "down_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
    use_gradient_checkpointing = "unsloth",
    random_state = 3407,
)

# 3. Load your dataset
dataset = load_dataset("json", data_files="dialogue_training.jsonl", split="train")

# 4. Format function for chat template
def formatting_prompts_func(examples):
    convos = examples["messages"]
    texts = [tokenizer.apply_chat_template(convo, tokenize=False, add_generation_prompt=False)
             for convo in convos]
    return {"text": texts}

dataset = dataset.map(formatting_prompts_func, batched=True)

# 5. Training
trainer = SFTTrainer(
    model = model,
    tokenizer = tokenizer,
    train_dataset = dataset,
    dataset_text_field = "text",
    max_seq_length = max_seq_length,
    dataset_num_proc = 2,
    packing = False,
    args = TrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps = 5,
        num_train_epochs = 3,  # Adjust based on dataset size
        learning_rate = 2e-4,
        fp16 = not torch.cuda.is_bf16_supported(),
        bf16 = torch.cuda.is_bf16_supported(),
        logging_steps = 1,
        optim = "adamw_8bit",
        weight_decay = 0.01,
        lr_scheduler_type = "linear",
        seed = 3407,
        output_dir = "outputs",
    ),
)

trainer.train()

# 6. Save the model
model.save_pretrained("my_dialogue_model")
tokenizer.save_pretrained("my_dialogue_model")
```

## Converting to GGUF

### Option 1: Using llama.cpp converter
```bash
# Install llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Convert HuggingFace to GGUF
python convert_hf_to_gguf.py /path/to/my_dialogue_model --outfile dialogue-model.gguf

# Quantize to 4-bit for performance
./llama-quantize dialogue-model.gguf dialogue-model-q4.gguf Q4_K_M
```

### Option 2: Using Unsloth's built-in converter
```python
# Add to your training script after saving
model.save_pretrained_gguf("dialogue_model", tokenizer, quantization_method="q4_k_m")
```

## Dataset Format Examples

### Simple Dialogue
```jsonl
{"messages": [{"role": "user", "content": "Hello"}, {"role": "assistant", "content": "Greetings, traveler. What brings you to my shop?"}]}
{"messages": [{"role": "user", "content": "Do you have any potions?"}, {"role": "assistant", "content": "Aye, I've got healing draughts and mana elixirs. What's your poison?"}]}
```

### Multi-turn Conversations
```jsonl
{"messages": [
  {"role": "user", "content": "I need help with a quest"},
  {"role": "assistant", "content": "Tell me more. What quest troubles you?"},
  {"role": "user", "content": "The dragon in the mountains"},
  {"role": "assistant", "content": "Ah, the ancient wyrm. You'll need fireproof armor and a sharp blade."}
]}
```

## Training Tips

1. **Dataset Size**:
   - Minimum: 100 examples
   - Good: 500-1000 examples
   - Better: 2000+ examples

2. **Epochs**:
   - Small dataset (100-500): 5-10 epochs
   - Medium dataset (500-2000): 3-5 epochs
   - Large dataset (2000+): 1-3 epochs

3. **Learning Rate**:
   - Start with 2e-4
   - If model forgets base knowledge: lower to 1e-4
   - If not learning style: increase to 5e-4

4. **Overfitting Prevention**:
   - Monitor training loss
   - Stop when loss plateaus
   - Use validation split if possible

## Testing Your Model

```python
# Quick test before converting
FastLanguageModel.for_inference(model)

inputs = tokenizer.apply_chat_template(
    [{"role": "user", "content": "What's your name?"}],
    tokenize=True,
    add_generation_prompt=True,
    return_tensors="pt"
).to("cuda")

outputs = model.generate(inputs, max_new_tokens=64, temperature=0.7)
print(tokenizer.decode(outputs[0]))
```

## Cost-Effective Options

### Free Options:
- **Google Colab** (free GPU for ~12 hours)
- **Kaggle Notebooks** (30hrs/week free GPU)
- **Lightning AI** (free tier with GPU)

### Paid Options:
- **RunPod** (~$0.20/hr for decent GPU)
- **Vast.ai** (~$0.10-0.30/hr)
- **Lambda Labs** (~$0.50/hr)

For a 1.5B model with 500 examples: ~30 minutes on free Colab!

## Next Steps

1. Create your dialogue dataset (see examples above)
2. Run training script on Colab/Kaggle
3. Convert to GGUF
4. Drop into `models/` folder
5. Update `chat_ui.gd` with new model path
6. Test in Godot!
