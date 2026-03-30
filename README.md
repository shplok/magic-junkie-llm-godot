# Magic Junkie LLM - Godot

Local LLM inference in Godot using the Godot LLM extension (powered by llama.cpp).

## Features

- **Fully Embedded**: No external servers, runs entirely in your game
- **GPU Accelerated**: Metal support on macOS (Vulkan on other platforms)
- **Chat Interface**: Simple UI for testing dialogue generation
- **Real-time Streaming**: See tokens generate live
- **Offline**: Everything runs locally

## Setup

1. **Download a GGUF model** (not included due to size):
   ```bash
   cd models/
   # Example: Qwen 2.5 1.5B (recommended for dialogue)
   curl -L -o qwen-1.5b-q4.gguf "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
   ```

2. **Open in Godot 4.6+**

3. **Run `npc_chat_test.tscn`** to test multiple NPCs
   - Press **1** to talk to Gareth the Merchant (MEAN)
   - Press **2** to talk to Captain Brutus (INDIFFERENT)
   - Press **3** to talk to Old Mara (KIND)
   - Press **ESC** to end conversation (clears memory)
   - Or run `chat_ui.tscn` for simple single-conversation chat

## Files

- `npc_chat_test.tscn` - **NEW!** Interactive NPC chat (press 1/2/3 to switch NPCs)
- `chat_ui.tscn` - Simple chat interface
- `test_llm_simple.tscn` - Simple generation test
- `npc_llm_handler.gd` - Singleton for managing multiple NPC conversations
- `system_prompts/` - NPC personality templates
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
- ~4-5GB free RAM (for Mistral 7B) or ~1-2GB (for Qwen 1.5B)
- GGUF model file

## Models Included

- **Mistral 7B Instruct** (`mistral-7b-instruct-q4.gguf`) - Default, better instruction following
- **Qwen 1.5B** (`qwen-1.5b-q4.gguf`) - Faster, uses less RAM

## Credits

- [Godot LLM Extension](https://github.com/Adriankhl/godot-llm) by adriankhl
- Powered by [llama.cpp](https://github.com/ggml-org/llama.cpp)
