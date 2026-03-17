# Magic Junkie LLM - Godot

Local LLM inference in Godot using the Godot LLM extension (powered by llama.cpp).

## Features

- 🎮 **Fully Embedded**: No external servers, runs entirely in your game
- 🚀 **GPU Accelerated**: Metal support on macOS (Vulkan on other platforms)
- 💬 **Chat Interface**: Simple UI for testing dialogue generation
- 🔄 **Real-time Streaming**: See tokens generate live
- 📦 **Offline**: Everything runs locally

## Setup

1. **Download a GGUF model** (not included due to size):
   ```bash
   cd models/
   # Example: Qwen 2.5 1.5B (recommended for dialogue)
   curl -L -o qwen-1.5b-q4.gguf "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
   ```

2. **Open in Godot 4.6+**

3. **Run `chat_ui.tscn`** to test the chat interface

## Files

- `chat_ui.tscn` - Interactive chat interface
- `test_llm_simple.tscn` - Simple generation test
- `addons/godot_llm/` - Pre-built Godot LLM extension
- `models/` - Place your .gguf models here

## Using in Your Game

```gdscript
var gdllama = GDLlama.new()
add_child(gdllama)
gdllama.model_path = "res://models/your-model.gguf"
gdllama.n_predict = 100
gdllama.generate_text_finished.connect(_on_response)
gdllama.run_generate_text("Your prompt here", "", "")

func _on_response(text):
    print("AI said: ", text)
```

## Requirements

- Godot 4.6+
- ~1-2GB free RAM (depending on model size)
- GGUF model file (1-4B parameters recommended)

## Credits

- [Godot LLM Extension](https://github.com/Adriankhl/godot-llm) by adriankhl
- Powered by [llama.cpp](https://github.com/ggml-org/llama.cpp)
