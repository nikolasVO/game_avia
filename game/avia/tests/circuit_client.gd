extends "res://main.gd"
const CircuitPilot=preload("res://tests/circuit_pilot.gd")
var pilot: CircuitPilot=CircuitPilot.new()
var completed: bool=false
var failed: bool=false
func _physics_process(_delta: float) -> void:
 if not session or not session.joined or session.local_state.is_empty():return
 var state: Dictionary=session.local_state
 if state.crashed:
  if not failed:print(JSON.stringify({"event":"circuit_failed","aircraft_id":AviaFlight.PLANES[int(state.plane)].aircraft_id,"stage":pilot.stage}))
  failed=true;session.controls=AviaFlight.neutral();return
 session.controls=pilot.command(state)
 if not completed and state.was_airborne and state.grounded and state.v.length()<2 and pilot.stage>=4:
  completed=true
  print(JSON.stringify({"event":"circuit_stopped","aircraft_id":AviaFlight.PLANES[int(state.plane)].aircraft_id,"peer":session.multiplayer.get_unique_id(),"age":state.age,"position":str(state.p),"distance_m":state.distance}))
