extends Control

@onready var output_text = $VBoxContainer/OutputPanel/OutputText
@onready var input_field = $VBoxContainer/InputPanel/HBoxContainer/InputField
@onready var send_button = $VBoxContainer/InputPanel/HBoxContainer/SendButton
@onready var status_label = $VBoxContainer/StatusLabel

var gdllama
var conversation_history = ""

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)

	status_label.text = "Loading model..."

	gdllama = GDLlama.new()
	add_child(gdllama)
	gdllama.model_path = "res://models/qwen-1.5b-q4.gguf"
	gdllama.n_predict = 150
	gdllama.should_output_prompt = false

	gdllama.generate_text_updated.connect(_on_text_updated)
	gdllama.generate_text_finished.connect(_on_text_finished)

	status_label.text = "Ready! Type a message and press Enter or Send."
	output_text.text = "Chat started. Ask anything!\n\n"

func _on_send_pressed():
	_send_message()

func _on_text_submitted(text: String):
	_send_message()

func _send_message():
	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	# Add user message to display
	output_text.text += "[b]You:[/b] " + user_input + "\n"
	conversation_history += "User: " + user_input + "\n"

	# Clear input
	input_field.text = ""

	# Show generating status
	status_label.text = "Generating response..."
	output_text.text += "[b]AI:[/b] "
	send_button.disabled = true

	# Generate response
	var prompt = conversation_history + "Assistant:"
	gdllama.run_generate_text(prompt, "", "")

func _on_text_updated(new_text):
	# Stream the response as it generates
	output_text.text += new_text

func _on_text_finished(final_text):
	# Clean up and prepare for next message
	conversation_history += "Assistant: " + final_text + "\n"
	output_text.text += "\n\n"
	status_label.text = "Ready! Type a message and press Enter or Send."
	send_button.disabled = false
	input_field.grab_focus()
