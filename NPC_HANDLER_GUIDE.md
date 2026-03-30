# NPC LLM Handler - Usage Guide

A centralized system for managing multiple NPC conversations with unique personalities and temporary memory.

## Overview

The `NPCLLMHandler` is a singleton that manages LLM-based conversations with multiple NPCs. Each NPC:
- Has a unique system prompt loaded from `system_prompts/{npc_name}.txt`
- Maintains temporary conversation history (local array)
- Memory is cleared when conversation ends
- Supports variable substitution in prompts
- **Auto-ends after 5 exchanges** and provides a persuasion score (0.0-1.0)
- Persuasion score indicates how convinced the NPC was to give the player what they want

## How It Works

1. **System Prompts**: Each NPC has a text file in `system_prompts/` with variable placeholders
2. **Temporary Memory**: Conversation history stored per NPC, cleared on `end_conversation()`
3. **Single Model Instance per NPC**: Each active conversation has its own GDLlama instance
4. **Automatic Cleanup**: Memory and resources freed when conversation ends

## Usage

### 1. Create a System Prompt

Create a file in `system_prompts/{npc_name}.txt` with variables:

```
You are {character_role} living in Balthemere...
Your name is {npc_name}.
Your disposition is {personality}...
{world_context}
{current_state_description}
```

### 2. Start a Conversation

```gdscript
var npc_vars = {
    "character_role": "a greedy merchant",
    "npc_name": "Gareth",
    "personality": "MEAN",
    "world_context": "The guards are cracking down.",
    "current_state_description": "Standing behind a cart."
}

NPCLLMHandler.start_conversation("merchant", npc_vars)
```

### 3. Send Messages

```gdscript
func talk_to_npc():
    NPCLLMHandler.send_message("merchant", "What are you selling?", _on_response, _on_evaluation)

func _on_response(npc_name: String, response: String):
    print("%s says: %s" % [npc_name, response])

func _on_evaluation(npc_name: String, persuasion_score: float):
    print("Persuasion score: %.2f" % persuasion_score)
    if persuasion_score >= 0.7:
        print("Success! NPC was convinced.")
        # Grant the player what they asked for
    else:
        print("Failed to convince NPC.")
```

### 4. End Conversation (Clears Memory)

```gdscript
NPCLLMHandler.end_conversation("merchant")
# All conversation history is now deleted
```

## API Reference

### `start_conversation(npc_name: String, variables: Dictionary) -> bool`
Start a new conversation with an NPC.
- **npc_name**: Must match a file in `system_prompts/{npc_name}.txt`
- **variables**: Dictionary of values to substitute in the prompt template
- **Returns**: `true` if successful, `false` if conversation already active or prompt not found

### `send_message(npc_name: String, user_message: String, callback: Callable, evaluation_callback: Callable = Callable()) -> bool`
Send a message to an NPC and get a response.
- **user_message**: What the player says
- **callback**: Function that receives `(npc_name: String, response: String)`
- **evaluation_callback**: Optional function that receives `(npc_name: String, persuasion_score: float)` when conversation auto-ends after 5 exchanges
- **Returns**: `true` if message sent, `false` if no active conversation

### `end_conversation(npc_name: String) -> void`
End conversation and clear all memory.
- Frees GDLlama instance
- Deletes conversation history
- Removes from active conversations

### `is_conversation_active(npc_name: String) -> bool`
Check if a conversation is currently active.

## Example: Multiple NPCs

```gdscript
# Talk to a merchant
NPCLLMHandler.start_conversation("merchant", merchant_vars)
NPCLLMHandler.send_message("merchant", "Hello", _on_merchant_response)

# Talk to a guard (different NPC, different memory)
NPCLLMHandler.start_conversation("guard", guard_vars)
NPCLLMHandler.send_message("guard", "Can I pass?", _on_guard_response)

# End both conversations when done
NPCLLMHandler.end_conversation("merchant")
NPCLLMHandler.end_conversation("guard")
```

## Memory Behavior

✅ **Memory Persists**: During an active conversation
- All messages are remembered
- NPC can reference previous exchanges

❌ **Memory Cleared**: When `end_conversation()` is called or after 5 exchanges
- Next conversation starts fresh
- NPC won't remember previous interactions

## Persuasion System

After **5 exchanges** (player message + NPC response = 1 exchange), the conversation auto-ends and evaluates:
- **0.0-0.3**: NPC was not convinced, player likely fails
- **0.4-0.6**: NPC is on the fence, partial success
- **0.7-1.0**: NPC was convinced, player likely succeeds

Factors that influence the score:
- **NPC Personality**: KIND NPCs are easily convinced, MEAN NPCs require strong leverage
- **Player's Arguments**: Offering value, appealing to NPC's interests
- **Conversation Flow**: Building rapport vs. being pushy

You can still manually end conversations early with `end_conversation()` (no evaluation score).

## Configuration

Edit `npc_llm_handler.gd` to change:
- `MODEL_PATH`: Path to your GGUF model
- `N_PREDICT`: Max tokens per response (default: 150)
- `SYSTEM_PROMPTS_DIR`: Where system prompts are stored

## Testing

Run `test_npc_handler.tscn` to see the system in action:
1. Starts conversation with merchant
2. Sends 2 messages
3. Ends conversation (clears memory)
4. Starts new conversation (different personality, no memory of previous chat)
