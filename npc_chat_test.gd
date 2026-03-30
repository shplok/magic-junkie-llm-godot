extends Control

@onready var output_text = $VBoxContainer/OutputPanel/OutputText
@onready var input_field = $VBoxContainer/InputPanel/HBoxContainer/InputField
@onready var send_button = $VBoxContainer/InputPanel/HBoxContainer/SendButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var npc_label = $VBoxContainer/NPCLabel

var current_npc = ""
var npc_configs = {
	"merchant": {
		"display_name": "Gareth the Merchant",
		"vars": {
			"character_role": "a greedy merchant selling stolen goods",
			"npc_name": "Gareth",
			"personality": "MEAN",
			"world_context": "The city guard is cracking down on black market trading.",
			"current_state_description": "Standing behind a cart of suspicious wares in a dark alley."
		}
	},
	"guard": {
		"display_name": "Captain Brutus",
		"vars": {
			"character_role": "a corrupt city guard",
			"npc_name": "Captain Brutus",
			"personality": "INDIFFERENT",
			"world_context": "The streets are filled with beggars and thieves.",
			"current_state_description": "Leaning against a wall, picking his teeth with a dagger."
		}
	},
	"beggar": {
		"display_name": "Old Mara",
		"vars": {
			"character_role": "a blind beggar who knows too much",
			"npc_name": "Old Mara",
			"personality": "KIND",
			"world_context": "The city's secrets flow through the gutters where she sits.",
			"current_state_description": "Sitting in rags on the cobblestones, holding out a tin cup."
		}
	}
}

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)

	status_label.text = "Press 1 (Merchant) | 2 (Guard) | 3 (Beggar) to start conversation"
	npc_label.text = "No active conversation"
	output_text.text = "[b]NPC Chat Test[/b]\n\n"
	output_text.text += "Press number keys to talk to different NPCs:\n"
	output_text.text += "1 - Gareth the Merchant (MEAN)\n"
	output_text.text += "2 - Captain Brutus (INDIFFERENT)\n"
	output_text.text += "3 - Old Mara (KIND)\n"
	output_text.text += "ESC - End current conversation\n\n"
	output_text.text += "[color=gray]Conversations auto-end after 5 exchanges and give a persuasion score (0.0-1.0)[/color]\n\n"

	input_field.editable = false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_switch_to_npc("merchant")
			KEY_2:
				_switch_to_npc("guard")
			KEY_3:
				_switch_to_npc("beggar")
			KEY_ESCAPE:
				_end_current_conversation()

func _switch_to_npc(npc_name: String):
	# End current conversation if any
	if current_npc != "" and current_npc != npc_name:
		_end_current_conversation()

	# Start new conversation if not already active
	if current_npc != npc_name:
		var config = npc_configs[npc_name]

		if NPCLLMHandler.start_conversation(npc_name, config.vars):
			current_npc = npc_name
			npc_label.text = "Talking to: " + config.display_name
			output_text.text += "\n[b]=== Started conversation with " + config.display_name + " ===[/b]\n\n"
			status_label.text = "Type a message and press Enter"
			input_field.editable = true
			input_field.grab_focus()
		else:
			output_text.text += "\n[color=red]Failed to start conversation with " + config.display_name + "[/color]\n"

func _end_current_conversation():
	if current_npc == "":
		return

	var config = npc_configs[current_npc]
	NPCLLMHandler.end_conversation(current_npc)
	output_text.text += "\n[b]=== Ended conversation with " + config.display_name + " (memory cleared) ===[/b]\n\n"

	current_npc = ""
	npc_label.text = "No active conversation"
	status_label.text = "Press 1 (Merchant) | 2 (Guard) | 3 (Beggar) to start conversation"
	input_field.editable = false
	input_field.text = ""

func _on_send_pressed():
	_send_message()

func _on_text_submitted(_text: String):
	_send_message()

func _send_message():
	if current_npc == "":
		return

	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	# Add user message to display
	output_text.text += "[b]You:[/b] " + user_input + "\n"

	# Clear input
	input_field.text = ""

	# Show generating status
	status_label.text = "Generating response..."
	send_button.disabled = true
	input_field.editable = false

	# Generate response (with evaluation callback)
	NPCLLMHandler.send_message(current_npc, user_input, _on_npc_response, _on_persuasion_evaluated)

func _on_npc_response(npc_name: String, response: String):
	var config = npc_configs[npc_name]
	output_text.text += "[b]" + config.display_name + ":[/b] " + response + "\n\n"

	status_label.text = "Type a message and press Enter (or press number to switch NPC, ESC to end)"
	send_button.disabled = false
	input_field.editable = true
	input_field.grab_focus()

	# Auto-scroll to bottom
	await get_tree().process_frame
	output_text.get_v_scroll_bar().value = output_text.get_v_scroll_bar().max_value

func _on_persuasion_evaluated(npc_name: String, score: float):
	var config = npc_configs[npc_name]
	output_text.text += "\n[color=yellow][b]=== Conversation Ended (5 exchanges) ===[/b][/color]\n"
	output_text.text += "[color=cyan]Persuasion Score: %.2f / 1.0[/color]\n" % score

	if score >= 0.7:
		output_text.text += "[color=green]Success! %s was convinced.[/color]\n\n" % config.display_name
	elif score >= 0.4:
		output_text.text += "[color=yellow]Maybe. %s is on the fence.[/color]\n\n" % config.display_name
	else:
		output_text.text += "[color=red]Failure. %s was not convinced.[/color]\n\n" % config.display_name

	current_npc = ""
	npc_label.text = "No active conversation"
	status_label.text = "Press 1 (Merchant) | 2 (Guard) | 3 (Beggar) to start conversation"
	input_field.editable = false
	input_field.text = ""

	# Auto-scroll to bottom
	await get_tree().process_frame
	output_text.get_v_scroll_bar().value = output_text.get_v_scroll_bar().max_value
