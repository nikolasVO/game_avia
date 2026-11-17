extends SceneTree
var checks: Array[Dictionary]=[]
var valid: bool=true
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"ok":ok});valid=valid and ok
func state(speed: float) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(3);s.p=Vector3(0,1000,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true;s.gear=false;s.profile=2
 return s
func _initialize() -> void:
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="f14":spec=row.duplicate(true)
 spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6
 check(AviaFighter.sweep_fraction(spec,180,false,false)==0.0 and AviaFighter.sweep_fraction(spec,255,false,false)==.5 and AviaFighter.sweep_fraction(spec,330,false,false)==1.0,"configured automatic schedule has exact open/middle/closed boundaries")
 check(AviaFighter.sweep_fraction(spec,600,true,false)==0.0 and AviaFighter.sweep_fraction(spec,600,false,true)==0.0,"gear and flaps interlocks affect physics schedule")
 var open: Dictionary=spec.duplicate(true);open.systems.variable_sweep=false
 var c: Dictionary=AviaFlight.neutral();c.gear=false;c.throttle=1.0;c.roll=.5
 var low: Dictionary=state(150);var low_sweep: Dictionary=AviaFighter.step_spec(low,c,spec);var low_open: Dictionary=AviaFighter.step_spec(low,c,open)
 check(low_sweep.v==low_open.v and low_sweep.rates==low_open.rates,"open low-speed wings preserve unswept forces exactly")
 var fast: Dictionary=state(350);var closed: Dictionary=AviaFighter.step_spec(fast,c,spec);var extended: Dictionary=AviaFighter.step_spec(fast,c,open)
 check(closed.v.z<extended.v.z and absf(closed.rates.z)<absf(extended.rates.z),"closed wings reduce base drag and control authority at high speed")
 # Below lift clamp, a separate full-sweep test schedule isolates aerodynamic effect.
 var lift_spec: Dictionary=spec.duplicate(true);lift_spec.sweep.start_speed_kmh=100.0;lift_spec.sweep.full_speed_kmh=200.0
 var sample: Dictionary=state(90);var swept_lift: Dictionary=AviaFighter.step_spec(sample,c,lift_spec);var open_lift: Dictionary=AviaFighter.step_spec(sample,c,open)
 check(swept_lift.v.y<open_lift.v.y-.01,"reduced swept lifting area changes actual vertical acceleration")
 var prediction: Dictionary=fast.duplicate(true);var authority: Dictionary=fast.duplicate(true)
 for tick: int in 60:
  prediction=AviaFighter.step_spec(prediction,c,spec);authority=AviaFighter.step_spec(authority,c,spec)
 check(prediction==authority and not authority.crashed,"same fixed-step schedule reproduces authority and prediction over 60 ticks")
 var untouched: bool=true
 for fighter: Dictionary in AviaFlight.PLANES:
  untouched=untouched and AviaFighter.sweep_fraction(fighter,400,false,false)==0.0
 check(untouched and AviaCatalog.index_of("f14")==-1,"all nine admitted aircraft remain unswept; F14 stays unavailable")
 print(JSON.stringify({"event":"sweep_flight_summary","status":"PASS" if valid else "FAIL","checks":checks,"measurements":{"closed_forward_mps":-closed.v.z,"open_forward_mps":-extended.v.z,"closed_roll_rate":closed.rates.z,"open_roll_rate":extended.rates.z,"closed_vertical_mps":swept_lift.v.y,"open_vertical_mps":open_lift.v.y},"scope":"deterministic authored arcade forces for planned prototype; no real F14 performance, takeoff/landing/network/device acceptance"}));quit(0 if valid else 1)
