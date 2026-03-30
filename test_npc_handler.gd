extends Node

# Example of how to use the NPCLLMHandler

func _ready():
	print("=== NPC LLM Handler Test ===\n")

	# The handler is automatically available as a singleton (NPCLLMHandler)
	# Wait a moment for everything to initialize
	await get_tree().create_timer(0.5).timeout

	# Test conversation with a merchant
	test_merchant_conversation()

func test_merchant_conversation():
	print("Starting conversation with merchant...\n")

	# Define the merchant's characteristics
	var merchant_vars = {
		"character_role": "a greedy merchant selling stolen goods",
		"npc_name": "Gareth the Swindler",
		"personality": "MEAN",
		"world_context": "The city guard is cracking down on black market trading.",
		"current_state_description": "Standing nervously behind a cart of suspicious-looking wares in a dark alley."
	}

	# Start the conversation
	if NPCLLMHandler.start_conversation("merchant", merchant_vars):
		# Send first message
		await get_tree().create_timer(1.0).timeout
		print("Player: What are you selling?\n")
		NPCLLMHandler.send_message("merchant", "What are you selling?", _on_merchant_response)

func _on_merchant_response(npc_name: String, response: String):
	print("%s: %s\n" % [npc_name, response])

	# Send another message after a delay
	await get_tree().create_timer(2.0).timeout
	print("Player: How much for that dagger?\n")
	NPCLLMHandler.send_message("merchant", "How much for that dagger?", _on_merchant_response_2)

func _on_merchant_response_2(npc_name: String, response: String):
	print("%s: %s\n" % [npc_name, response])

	# End conversation
	await get_tree().create_timer(2.0).timeout
	print("=== Ending conversation ===")
	NPCLLMHandler.end_conversation("merchant")

	# Test starting a new conversation (memory should be cleared)
	await get_tree().create_timer(1.0).timeout
	test_new_conversation()

func test_new_conversation():
	print("\n=== Testing new conversation (memory cleared) ===\n")

	var merchant_vars = {
		"character_role": "a greedy merchant selling stolen goods",
		"npc_name": "Gareth the Swindler",
		"personality": "INDIFFERENT",  # Changed personality!
		"world_context": "The market is bustling today.",
		"current_state_description": "Counting coins at his stall."
	}

	if NPCLLMHandler.start_conversation("merchant", merchant_vars):
		await get_tree().create_timer(1.0).timeout
		print("Player: What are you selling?\n")
		NPCLLMHandler.send_message("merchant", "What are you selling?", _on_new_response)

func _on_new_response(npc_name: String, response: String):
	print("%s: %s\n" % [npc_name, response])
	print("(Notice: merchant should not remember previous conversation)")

	await get_tree().create_timer(2.0).timeout
	NPCLLMHandler.end_conversation("merchant")
	print("\n=== Test Complete ===")
