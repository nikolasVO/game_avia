extends "res://main.gd"
func _ready() -> void:
 super._ready()
 if session.server:session.state_audit.connect(_state)
func _state(id: int,state: Dictionary,ack: int) -> void:
 if int(state.age) % 15!=0:return
 print(JSON.stringify({"event":"authority_state","peer":id,"plane":state.plane,"profile":state.profile,"age":state.age,"ack":ack,"afterburner":state.afterburner,"gear":state.gear,"flaps":state.flaps,"airbrake":state.airbrake,"crashed":state.crashed,"was_airborne":state.was_airborne,"position":str(state.p),"velocity":str(state.v)}))
