extends SceneTree
## Development pilot: commands only, from parked spawn through circuit and approach.
## Failures describe this pilot/scenario, not physical-device or human acceptance.
func _initialize() -> void:
 var results: Array[Dictionary]=[]
 for index: int in range(3,9):
  var s: Dictionary=AviaFlight.spawn(index);var pilot: RefCounted=preload("res://tests/circuit_pilot.gd").new();var samples: Array=[]
  var landed_tick: int=-1;var takeoff_tick: int=-1;var bank_max: float=0
  for tick: int in 18000:
   var c: Dictionary=pilot.command(s)
   s=AviaFlight.step(s,c)
   bank_max=maxf(bank_max,absf(float(s.roll)))
   if s.was_airborne and takeoff_tick<0:takeoff_tick=tick
   if tick%30==0:samples.append({"seconds":tick/30.0,"x":s.p.x,"y":s.p.y,"z":s.p.z,"speed":s.v.length(),"vy":s.v.y,"yaw":s.yaw,"roll":s.roll,"pitch":s.pitch,"stage":pilot.stage,"throttle":c.throttle})
   if s.landed:landed_tick=tick
   if s.crashed or (landed_tick>=0 and s.v.length()<2):break
  results.append({"aircraft_id":AviaFlight.PLANES[index].aircraft_id,"status":"PASS" if landed_tick>=0 and not s.crashed and s.v.length()<2 else "FAIL","takeoff_seconds":takeoff_tick/30.0,"landing_seconds":landed_tick/30.0,"stage":pilot.stage,"crashed":s.crashed,"final_position":str(s.p),"final_speed_mps":s.v.length(),"max_bank_rad":bank_max,"samples":samples})
 var report: Dictionary={"scope":"command-only development pilot; parked spawn/circuit/approach. Not human/network/device proof. No coordinate injection.","source":"current shared fighter_v1 unchanged from f702","results":results}
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size():var f: FileAccess=FileAccess.open(args[0],FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
 for row: Dictionary in results:
  var summary: Dictionary=row.duplicate();summary.erase("samples");print(JSON.stringify(summary))
 quit(0 if results.all(func(r: Dictionary):return r.status=="PASS") else 1)
