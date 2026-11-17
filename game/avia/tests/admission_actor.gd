extends "res://net/session.gd"
var scenario: String="replay"
var offered: bool=false
@rpc("authority","call_remote","reliable",0)
func admission_ticket(token: String) -> void:
 offered=true
 if scenario=="expired":
  await get_tree().create_timer(3.3).timeout
  redeem_ticket.rpc_id(1,token)
 else:
  redeem_ticket.rpc_id(1,token)
  await get_tree().create_timer(0.3).timeout
  redeem_ticket.rpc_id(1,token)
