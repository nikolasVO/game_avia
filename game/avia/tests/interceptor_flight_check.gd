extends SceneTree
## Compare shared arcade forces with a planned heavy interceptor; no true envelope claim.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func sample(speed: float,altitude: float=1000) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(3);s.p=Vector3(0,altitude,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true;s.gear=false;s.profile=2;return s
func _initialize() -> void:
 var before: String=JSON.stringify(AviaCatalog.all());var values: Array[Dictionary]=[]
 for id: String in ["mig31","f16c"]:
  var spec: Dictionary={}
  for row: Dictionary in AviaCatalog.all():
   if row.aircraft_id==id:spec=row.duplicate(true)
  spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6
  var c: Dictionary=AviaFlight.neutral();c.gear=false;c.throttle=.4;c.roll=.3
  var low: Dictionary=sample(90);var fast: Dictionary=sample(200)
  for tick: int in 30:low=AviaFighter.step_spec(low,c,spec);fast=AviaFighter.step_spec(fast,c,spec)
  var bank: float=absf(low.roll);c.roll=0
  var residual_start: float=absf(low.rates.z)
  for tick: int in 10:low=AviaFighter.step_spec(low,c,spec)
  var residual: float=absf(low.rates.z)/maxf(.001,residual_start)
  var dry: Dictionary=sample(150);var boost: Dictionary=dry.duplicate();c=AviaFlight.neutral();c.gear=false;c.throttle=1
  for tick: int in 120:
   dry=AviaFighter.step_spec(dry,c,spec);c.afterburner=true;boost=AviaFighter.step_spec(boost,c,spec);c.afterburner=false
  check(boost.v.length()>dry.v.length()+8,id+": afterburner changes actual acceleration")
  # Current world ends at2500m: exercise density within the actual playable boundary.
  var sea: Dictionary=sample(500,100);var high: Dictionary=sample(500,2000);c.afterburner=true
  for tick: int in 120:sea=AviaFighter.step_spec(sea,c,spec);high=AviaFighter.step_spec(high,c,spec)
  check(not sea.crashed and not high.crashed and high.v.length()>sea.v.length()+5,id+": achievable speed changes with density/altitude inside current world")
  values.append({"aircraft_id":id,"low_speed_bank_rad":bank,"fast_bank_rad":absf(fast.roll),"residual_roll_fraction":residual,"dry4s_mps":dry.v.length(),"boost4s_mps":boost.v.length(),"sea4s_mps":sea.v.length(),"altitude4s_mps":high.v.length()})
 check(values[0].low_speed_bank_rad<values[1].low_speed_bank_rad*.6,"heavy interceptor has materially less low-speed roll authority than light F16")
 check(values[0].residual_roll_fraction>values[1].residual_roll_fraction,"heavy interceptor retains more angular inertia after release")
 check(values[0].altitude4s_mps>values[1].altitude4s_mps+30,"interceptor trades close manoeuvres for faster altitude envelope")
 check(AviaCatalog.index_of("mig31")==-1 and AviaFlight.PLANES.size()==9 and JSON.stringify(AviaCatalog.all())==before,"isolated planned test preserves playable catalog")
 var passed: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"interceptor_flight_summary","status":"PASS" if passed else "FAIL","checks":checks,"measurements":values,"scope":"actual shared-force game balance only; no real flight, human/network/phone or production acceptance"}));quit(0 if passed else 1)
