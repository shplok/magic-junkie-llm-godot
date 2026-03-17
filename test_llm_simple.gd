extends Node

var gdllama

func _ready():
	print("=== Godot LLM Test ===")

	gdllama = GDLlama.new()
	add_child(gdllama)
	gdllama.model_path = "res://models/qwen-1.5b-q4.gguf"
	gdllama.n_predict = 100
	gdllama.should_output_prompt = false
	gdllama.generate_text_updated.connect(_on_text_updated)
	gdllama.generate_text_finished.connect(_on_text_finished)

	gdllama.run_generate_text("Once upon a time", "", "")

func _on_text_updated(new_text):
	print("Generating: ", new_text)

func _on_text_finished(final_text):
	print("\n=== Complete ===")
	print(final_text)
