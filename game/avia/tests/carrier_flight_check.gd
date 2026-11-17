extends SceneTree
## Actual shared forces with isolated planned specs, no new aircraft admitted.
var checks: Array[Dictionary]=[]
var measurements: Array[Dictionary]=[]
var valid: bool=true
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"ok":ok});valid=valid and ok
func sample(spec: Dictionary,speed: float) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(3);s.p=Vector3(0,1000,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true;s.gear=false;s.profile=2
 return s
func _initialize() -> void:
 var specs: Array[Dictionary]=[]
 for id: String in ["fa18e","f15c"]:
  for row: Dictionary in AviaCatalog.all():
   if row.aircraft_id==id:
    var spec: Dictionary=row.duplicate(true);spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6;specs.append(spec)
 var original: String=JSON.stringify(AviaCatalog.all())
 for spec: Dictionary in specs:
  var c: Dictionary=AviaFlight.neutral();c.gear=false;c.roll=.3;c.throttle=.4
  var low: Dictionary=sample(spec,65);var high: Dictionary=sample(spec,160)
  for tick: int in 30:low=AviaFighter.step_spec(low,c,spec);high=AviaFighter.step_spec(high,c,spec)
  c=AviaFlight.neutral();c.gear=false;c.throttle=1
  var dry: Dictionary=sample(spec,110);var boosted: Dictionary=dry.duplicate()
  for tick: int in 120:
   dry=AviaFighter.step_spec(dry,c,spec);c.afterburner=true;boosted=AviaFighter.step_spec(boosted,c,spec);c.afterburner=false
  check(boosted.v.length()>dry.v.length()+8 and not dry.crashed and not boosted.crashed,spec.aircraft_id+": afterburner adds actual acceleration")
  var lowered: Dictionary=sample(spec,60);lowered.gear=true;var clean: Dictionary=lowered.duplicate();c=AviaFlight.neutral();c.throttle=.3;c.flaps=true
  lowered=AviaFighter.step_spec(lowered,c,spec);c.flaps=false;clean=AviaFighter.step_spec(clean,c,spec)
  check(lowered.v.y>clean.v.y,spec.aircraft_id+": flaps change low-speed vertical force")
  measurements.append({"aircraft_id":spec.aircraft_id,"low_speed_bank_rad":absf(low.roll),"high_speed_bank_rad":absf(high.roll),"dry_4s_mps":dry.v.length(),"afterburner_4s_mps":boosted.v.length(),"flap_vertical_delta_mps":lowered.v.y-clean.v.y})
 check(float(measurements[0].low_speed_bank_rad)>float(measurements[1].low_speed_bank_rad)*1.3,"FA18E retains materially more low-speed roll authority than heavy F15C under identical commands")
 check(float(measurements[1].afterburner_4s_mps)>float(measurements[0].afterburner_4s_mps)+8,"F15C accelerates faster; carrier low-speed control has a speed tradeoff")
 check(AviaCatalog.index_of("fa18e")==-1 and AviaFlight.PLANES.size()==9 and JSON.stringify(AviaCatalog.all())==original,"isolated planned behavior test does not mutate catalog or playable admission")
 print(JSON.stringify({"event":"carrier_flight_summary","status":"PASS" if valid else "FAIL","checks":checks,"measurements":measurements,"scope":"authored shared-force behavior only, no real flight envelope or human/network/phone acceptance"}));quit(0 if valid else 1)
