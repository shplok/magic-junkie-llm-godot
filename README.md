# Magic Junkie LLM - Godot

Local LLM-powered NPC conversations with persuasion mechanics. Built with Godot and llama.cpp.

## Features

- 🎮 **NPC Persuasion System**: Players try to convince NPCs over 5-exchange conversations
- 📊 **Persuasion Scoring**: AI evaluates player success (0.0-1.0) based on NPC personality
- 🎭 **Dynamic Personalities**: KIND (easy), INDIFFERENT (moderate), MEAN (hard to convince)
- 💬 **Real-time Streaming**: See NPC responses generate live
- 🔄 **Memory Management**: Temporary chat history, clears between conversations
- 🚀 **Fully Local**: No API calls, runs entirely offline in your game
- ⚡ **GPU Accelerated**: Metal on macOS, Vulkan on other platforms

## Setup

1. **Download Mistral 7B model** (recommended, ~4GB):
   ```bash
   cd models/
   curl -L -o mistral-7b-instruct-q4.gguf "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf"
   ```

   *Or for faster/lower memory: Qwen 1.5B (~1GB)*
   ```bash
   curl -L -o qwen-1.5b-q4.gguf "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
   # Then change MODEL_PATH in npc_llm_handler.gd
   ```

2. **Open in Godot 4.6+**

3. **Run `npc_chat_test.tscn`** to test the NPC persuasion system
   - Press **1** - Gareth the Merchant (MEAN - hard to convince)
   - Press **2** - Captain Brutus the Guard (INDIFFERENT - moderate)
   - Press **3** - Old Mara the Beggar (KIND - easy to convince)
   - Try to convince them over 5 exchanges
   - Get a persuasion score (0.0-1.0) when conversation ends
   - Press **ESC** to end early (no score)

## Files

- `npc_chat_test.tscn` - Interactive NPC persuasion demo (press 1/2/3 to talk)
- `npc_llm_handler.gd` - Singleton managing conversations, memory, and persuasion scoring
- `system_prompts/` - NPC personality templates (merchant, guard, beggar)
- `NPC_HANDLER_GUIDE.md` - Full API documentation
- `addons/godot_llm/` - Godot LLM extension (llama.cpp)
- `models/` - Place your .gguf models here
- `archive/` - Old test files (not tracked in git)

## Using in Your Game

```gdscript
# Start conversation with an NPC
var npc_vars = {
	"character_role": "a greedy merchant",
	"npc_name": "Gareth",
	"personality": "MEAN",
	"world_context": "The guards are cracking down.",
	"current_state_description": "Behind a cart of stolen goods."
}

NPCLLMHandler.start_conversation("merchant", npc_vars)

# Send messages
NPCLLMHandler.send_message("merchant", "Can I have some gold?",
	_on_npc_response,      # Called each exchange
	_on_persuasion_score   # Called after 5 exchanges
)

func _on_npc_response(npc_name: String, response: String):
	show_dialogue(response)

func _on_persuasion_score(npc_name: String, score: float):
	if score >= 0.7:
		give_player_gold()  # NPC was convinced!
	else:
		print("Failed to convince NPC")

# End conversation (clears memory)
NPCLLMHandler.end_conversation("merchant")
```

See `NPC_HANDLER_GUIDE.md` for full API documentation.

## Requirements

- **Godot 4.6+**
- **~4-5GB free RAM** (for Mistral 7B) or ~1-2GB (for Qwen 1.5B)
- **GGUF model file** (download via setup instructions)

## Model Recommendations

- **Mistral 7B Instruct** (default) - Better at following instructions, staying in character
- **Qwen 1.5B** - Faster, lower RAM, but may be less consistent with prompts

## How It Works

1. **5 Exchange Limit**: Conversations auto-end after 5 player/NPC exchanges
2. **Persuasion Evaluation**: LLM analyzes the conversation and rates 0.0-1.0
3. **Personality Matters**: KIND NPCs are easier to convince than MEAN NPCs
4. **Memory Cleared**: Each conversation starts fresh, no persistent memory
5. **Sliding Window**: Only recent exchanges sent to model to prevent context overflow

## Persuasion Scoring

After 5 exchanges, the AI evaluates how convinced the NPC was:

- **0.0-0.3** 🔴 Failure - NPC refused, was hostile, or said no
- **0.4-0.6** 🟡 Maybe - NPC was neutral, didn't commit
- **0.7-1.0** 🟢 Success - NPC agreed or was willing to help

**Tips for convincing NPCs:**
- KIND personality: Be friendly, they want to help
- INDIFFERENT: Offer value or mutual benefit
- MEAN: Need strong leverage, threats won't work on them

## Credits

- [Godot LLM Extension](https://github.com/Adriankhl/godot-llm) by adriankhl
- Powered by [llama.cpp](https://github.com/ggml-org/llama.cpp)
- Using [Mistral 7B Instruct](https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF) by TheBloke
