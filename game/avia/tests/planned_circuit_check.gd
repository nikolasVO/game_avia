extends SceneTree
## Commands only through the normal shared force model; never admits planned types.
func _initialize() -> void:
 var aircraft_id: String="f14";var output: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--aircraft-id="):aircraft_id=arg.trim_prefix("--aircraft-id=")
  elif arg.begins_with("--out="):output=arg.trim_prefix("--out=")
  elif not arg.begins_with("--"):output=arg # Preserve prior positional evidence path.
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id==aircraft_id:spec=row.duplicate(true)
 if spec.is_empty() or bool(spec.playable) or spec.physics_model!="fighter_v1":
  push_error("planned_fighter_required");quit(1);return
 spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6
 var s: Dictionary=AviaFlight.spawn(3);var pilot: RefCounted=preload("res://tests/circuit_pilot.gd").new()
 var takeoff: int=-1;var landing: int=-1;var max_height: float=0;var max_speed: float=0;var samples: Array[Dictionary]=[];var commands_ok: bool=true
 for tick: int in 18000:
  var c: Dictionary=pilot.command_spec(s,spec);commands_ok=commands_ok and AviaFlight.valid_input(c)
  s=AviaFighter.step_spec(s,c,spec)
  max_height=maxf(max_height,s.p.y);max_speed=maxf(max_speed,s.v.length())
  if s.was_airborne and takeoff<0:takeoff=tick
  if s.landed:landing=tick
  if tick%30==0:samples.append({"seconds":tick*AviaFlight.DT,"position":[s.p.x,s.p.y,s.p.z],"speed_mps":s.v.length(),"stage":pilot.stage})
  if s.crashed or (landing>=0 and s.v.length()<2):break
 var passed: bool=commands_ok and takeoff>=0 and landing>takeoff and pilot.stage==4 and not s.crashed and s.v.length()<2 and s.distance>10000 and AviaCatalog.index_of(aircraft_id)==-1 and AviaFlight.PLANES.size()==9
 var result: Dictionary={"event":"planned_circuit_summary","status":"PASS" if passed else "FAIL","aircraft_id":aircraft_id,"takeoff_seconds":takeoff*AviaFlight.DT,"landing_seconds":landing*AviaFlight.DT,"crashed":s.crashed,"stage":pilot.stage,"final_speed_mps":s.v.length(),"distance_m":s.distance,"maximum_altitude_m":max_height,"maximum_speed_mps":max_speed,"commands_valid":commands_ok,"production_accepted":false,"scope":"planned-only command-driven parked/takeoff/circuit/approach/braked-stop simulation; no coordinate injection; no human/network/device acceptance","samples":samples}
 if not output.is_empty():
  var f: FileAccess=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 result.erase("samples");print(JSON.stringify(result));quit(0 if passed else 1)
