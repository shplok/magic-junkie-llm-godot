extends Node

# Central handler for managing multiple NPC LLM conversations
# Each NPC has its own temporary chat history that clears when conversation ends

const SYSTEM_PROMPTS_DIR = "res://system_prompts/"
const MODEL_PATH = "res://models/mistral-7b-instruct-q4.gguf"  # Mistral 7B - better instruction following
const N_PREDICT = 175  # Hard limit to prevent rambling
const HISTORY_WINDOW = 6  # Only keep last 6 messages (3 exchanges) in prompt to avoid context overflow

# Active conversations: {npc_name: {history: [], system_prompt: "", gdllama: GDLlama, callback: Callable, exchange_count: int}}
var active_conversations = {}

const MAX_EXCHANGES = 5  # Auto-end after 5 back-and-forth exchanges

func start_conversation(npc_name: String, variables: Dictionary) -> bool:
	"""
	Start a new conversation with an NPC
	Args:
		npc_name: Name of the NPC (matches system prompt filename)
		variables: Dictionary of variables to substitute in the system prompt
			Example: {
				"character_role": "merchant",
				"npc_name": "Gareth",
				"personality": "MEAN",
				"world_context": "The market is closing down.",
				"current_state_description": "Standing behind a cart of rotting fruit."
			}
	Returns:
		true if conversation started successfully, false otherwise
	"""
	if active_conversations.has(npc_name):
		push_warning("Conversation with %s already active" % npc_name)
		return false

	# Load system prompt template
	var prompt_path = SYSTEM_PROMPTS_DIR + npc_name + ".txt"
	var system_prompt = _load_system_prompt(prompt_path, variables)
	if system_prompt == "":
		push_error("Failed to load system prompt for %s at %s" % [npc_name, prompt_path])
		return false

	# Initialize GDLlama instance
	var gdllama = GDLlama.new()
	add_child(gdllama)
	gdllama.model_path = MODEL_PATH
	gdllama.n_predict = N_PREDICT
	gdllama.should_output_prompt = false

	# Store conversation state
	active_conversations[npc_name] = {
		"history": [],
		"system_prompt": system_prompt,
		"gdllama": gdllama,
		"callback": null,
		"current_response": "",
		"exchange_count": 0,
		"evaluation_callback": null
	}

	print("Started conversation with %s" % npc_name)
	return true

func send_message(npc_name: String, user_message: String, response_callback: Callable, evaluation_callback: Callable = Callable()) -> bool:
	"""
	Send a message to an NPC and get a response
	Args:
		npc_name: Name of the NPC
		user_message: The player's message
		response_callback: Callable that receives (npc_name: String, response: String)
		evaluation_callback: Optional Callable that receives (npc_name: String, persuasion_score: float) when conversation ends
	Returns:
		true if message sent successfully, false otherwise
	"""
	if not active_conversations.has(npc_name):
		push_error("No active conversation with %s" % npc_name)
		return false

	var conv = active_conversations[npc_name]

	# Add user message to history
	conv.history.append("Player: " + user_message)

	# Build prompt with sliding window: system prompt + recent history only
	var full_prompt = conv.system_prompt + "\n\n"

	# Use only the last HISTORY_WINDOW messages to keep prompt short
	var recent_history = conv.history
	if conv.history.size() > HISTORY_WINDOW:
		recent_history = conv.history.slice(conv.history.size() - HISTORY_WINDOW, conv.history.size())

	for msg in recent_history:
		full_prompt += msg + "\n"
	full_prompt += "Assistant:"

	# Store callbacks
	conv.callback = response_callback
	conv.current_response = ""
	if evaluation_callback.is_valid():
		conv.evaluation_callback = evaluation_callback

	# Connect signals if not already connected
	var gdllama = conv.gdllama
	if not gdllama.generate_text_updated.is_connected(_on_text_updated):
		gdllama.generate_text_updated.connect(_on_text_updated.bind(npc_name))
	if not gdllama.generate_text_finished.is_connected(_on_text_finished):
		gdllama.generate_text_finished.connect(_on_text_finished.bind(npc_name))

	# Generate response
	gdllama.run_generate_text(full_prompt, "", "")

	return true

func end_conversation(npc_name: String) -> void:
	"""
	End a conversation with an NPC and clear all memory
	"""
	if not active_conversations.has(npc_name):
		push_warning("No active conversation with %s to end" % npc_name)
		return

	var conv = active_conversations[npc_name]

	# Disconnect signals
	var gdllama = conv.gdllama
	if gdllama.generate_text_updated.is_connected(_on_text_updated):
		gdllama.generate_text_updated.disconnect(_on_text_updated)
	if gdllama.generate_text_finished.is_connected(_on_text_finished):
		gdllama.generate_text_finished.disconnect(_on_text_finished)

	# Free GDLlama instance
	gdllama.queue_free()

	# Remove from active conversations
	active_conversations.erase(npc_name)

	print("Ended conversation with %s (memory cleared)" % npc_name)

func is_conversation_active(npc_name: String) -> bool:
	"""Check if a conversation with an NPC is currently active"""
	return active_conversations.has(npc_name)

func _load_system_prompt(path: String, variables: Dictionary) -> String:
	"""Load system prompt from file and substitute variables"""
	if not FileAccess.file_exists(path):
		push_error("System prompt file not found: %s" % path)
		return ""

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open system prompt: %s" % path)
		return ""

	var template = file.get_as_text()
	file.close()

	# Substitute variables
	for key in variables:
		var placeholder = "{" + key + "}"
		template = template.replace(placeholder, str(variables[key]))

	return template

func _on_text_updated(new_text: String, npc_name: String) -> void:
	"""Called when LLM generates new tokens (streaming)"""
	if active_conversations.has(npc_name):
		active_conversations[npc_name].current_response += new_text

func _on_text_finished(final_text: String, npc_name: String) -> void:
	"""Called when LLM finishes generating response"""
	if not active_conversations.has(npc_name):
		return

	var conv = active_conversations[npc_name]

	# Check if this is an evaluation response
	if conv.has("is_evaluating") and conv.is_evaluating:
		var score = _parse_persuasion_score(final_text)
		conv.is_evaluating = false

		# Call evaluation callback
		if conv.evaluation_callback and conv.evaluation_callback.is_valid():
			conv.evaluation_callback.call(npc_name, score)

		# Auto-end conversation after evaluation
		end_conversation(npc_name)
		return

	# Clean the response (remove any continuation of conversation)
	var cleaned_text = _clean_response(final_text)

	# Add AI response to history
	conv.history.append("Assistant: " + cleaned_text)

	# Increment exchange count
	conv.exchange_count += 1

	# Call the response callback
	if conv.callback:
		conv.callback.call(npc_name, cleaned_text)

	# Clear current response
	conv.current_response = ""

	# Check if we've reached max exchanges
	if conv.exchange_count >= MAX_EXCHANGES:
		_evaluate_conversation(npc_name)

func _clean_response(text: String) -> String:
	"""Remove any unwanted continuation where the model keeps generating the conversation"""
	var stop_patterns = ["Player:", "\nPlayer:", "You:", "\nYou:", "\nAssistant:", "Assistant:"]

	var earliest_stop = -1
	for pattern in stop_patterns:
		var pos = text.find(pattern)
		if pos != -1:
			if earliest_stop == -1 or pos < earliest_stop:
				earliest_stop = pos

	if earliest_stop != -1:
		text = text.substr(0, earliest_stop)

	# Also trim any trailing whitespace
	return text.strip_edges()

func _evaluate_conversation(npc_name: String) -> void:
	"""Evaluate how convincing the player was in the conversation"""
	if not active_conversations.has(npc_name):
		return

	var conv = active_conversations[npc_name]

	# Build conversation summary
	var conversation_log = ""
	for msg in conv.history:
		conversation_log += msg + "\n"

	# Build evaluation prompt
	var eval_prompt = """You just had this conversation:

%s

Based on your personality (%s) and this conversation, rate from 0.0 to 1.0 how convinced you are to give the player what they want:
- 0.0 = Not convinced at all, refused completely
- 0.3 = Slightly swayed but still no
- 0.5 = On the fence, could go either way
- 0.7 = Mostly convinced, leaning yes
- 1.0 = Fully convinced, definitely yes

Consider: Did they offer something valuable? Did they appeal to your personality? Were they persuasive?

Reply with ONLY a number between 0.0 and 1.0, nothing else.""" % [conversation_log, conv.system_prompt.split("Personality:")[1].split("RULES:")[0].strip()]

	# Mark as evaluating
	conv.is_evaluating = true

	# Generate evaluation
	conv.gdllama.run_generate_text(eval_prompt, "", "")

func _parse_persuasion_score(text: String) -> float:
	"""Extract the persuasion score from the model's response"""
	# Clean the text
	text = text.strip_edges()

	# Try to find a float in the text
	var regex = RegEx.new()
	regex.compile("\\d+\\.\\d+|\\d+")
	var result = regex.search(text)

	if result:
		var score = float(result.get_string())
		# Clamp between 0.0 and 1.0
		return clamp(score, 0.0, 1.0)

	# Default to 0.5 if parsing fails
	push_warning("Failed to parse persuasion score from: %s" % text)
	return 0.5
