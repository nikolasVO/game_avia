extends "res://main.gd"
func _ready() -> void:
 session=load("res://tests/audit_server.gd").new();session.name="Session";add_child(session)
 var result: Error=session.start_server(24575)
 if result!=OK:get_tree().quit(1)
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--stats="):session.stats_path=arg.trim_prefix("--stats=")
 duration=80
