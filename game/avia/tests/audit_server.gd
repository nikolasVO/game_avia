extends "res://net/session.gd"
## Test observer attached to the production handler, with no replacement validation/RPCs.
func _ready() -> void:
 input_audit.connect(func(id: int, number: int, result: String):
  print(JSON.stringify({"event":"input_receipt","peer":id,"number":number,"result":result,"fire":bool(players[id].input.fire) if players.has(id) and result=="accepted" else false})))
 admission_audit.connect(func(id: int, result: String):
  print(JSON.stringify({"event":"ticket_receipt","peer":id,"result":result})))
