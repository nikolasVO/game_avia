extends SceneTree
var failed: int=0
var checks: Array[Dictionary]=[]
var measurements: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"status":"PASS" if ok else "FAIL"})
 if not ok:failed+=1
func airborne(index: int,speed: float=110.0) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(index);s.p=Vector3(0,1000,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true
 return s
func _initialize() -> void:
 check(AviaCatalog.all().size()==27 and AviaFlight.PLANES.size()==9,"24 configured fighters plus three originals; six selectable fighter prototypes")
 for index: int in range(3,9):
  var spec: Dictionary=AviaFlight.PLANES[index]
  var c: Dictionary=AviaFlight.neutral();c.throttle=1.0
  var takeoff: Dictionary=AviaFlight.spawn(index)
  var takeoff_tick: int=-1
  for tick: int in 240:
   c.pitch=clampf((0.15-float(takeoff.pitch))*3,-1,1)
   takeoff=AviaFlight.step(takeoff,c)
   if takeoff.was_airborne and takeoff_tick<0:takeoff_tick=tick
  check(takeoff_tick>=0 and not takeoff.crashed and takeoff.p.y>10,spec.aircraft_id+" actual shared-simulation ground roll and flight")
  c=AviaFlight.neutral();c.throttle=1.0;c.gear=false
  var normal: Dictionary=airborne(index);var ab: Dictionary=airborne(index)
  for tick: int in 120:
   normal=AviaFlight.step(normal,c);var boosted: Dictionary=c.duplicate();boosted.afterburner=true;ab=AviaFlight.step(ab,boosted)
  check(ab.v.length()>normal.v.length()+8 and not ab.crashed,spec.aircraft_id+" afterburner increases acceleration through thrust")
  var bank: Dictionary=airborne(index);c.roll=1.0
  for tick: int in 30:bank=AviaFlight.step(bank,c)
  var braked: Dictionary=airborne(index,150);var coast: Dictionary=braked.duplicate();c=AviaFlight.neutral();c.gear=false
  for tick: int in 90:
   coast=AviaFlight.step(coast,c);c.brake=true;braked=AviaFlight.step(braked,c);c.brake=false
  check(braked.v.length()<coast.v.length()-15,spec.aircraft_id+" airborne speed brake dissipates energy")
  var landing: Dictionary=airborne(index,50);landing.p=Vector3(0,1.41,0);landing.v.y=-2
  c=AviaFlight.neutral();c.flaps=true
  var result: Dictionary=AviaFlight.step(landing,c)
  check(result.landed and result.grounded and not result.crashed,spec.aircraft_id+" gentle configured gear-down touchdown")
  c.gear=false
  check(AviaFlight.step(landing,c).crashed,spec.aircraft_id+" gear-up impact rejected")
  # Round-trip angular inertia, assistance category and aircraft systems for reconciliation.
  bank.profile=2;bank.gear=false;bank.flaps=true;bank.afterburner=true
  var decoded: Dictionary=AviaWire.unpack(AviaWire.pack({25:{"state":bank,"ack":40,"race":{},"score":0}}))
  check(decoded.has(25) and decoded[25].state.rates.distance_to(bank.rates)<=0.028 and decoded[25].state.profile==2 and decoded[25].state.flaps and not decoded[25].state.gear,spec.aircraft_id+" full prediction state roundtrip in 84 bytes")
  measurements.append({"aircraft_id":spec.aircraft_id,"takeoff_seconds":float(takeoff_tick)/30,"altitude_after_8s_m":takeoff.p.y,"normal_speed_after_4s_mps":normal.v.length(),"afterburner_speed_after_4s_mps":ab.v.length(),"bank_after_1s_rad":bank.roll,"coast_after_3s_mps":coast.v.length(),"airbrake_after_3s_mps":braked.v.length()})
 check(absf(float(measurements[0].bank_after_1s_rad)-float(measurements[1].bank_after_1s_rad))>0.06 and absf(float(measurements[0].takeoff_seconds)-float(measurements[1].takeoff_seconds))>0.1,"F-16C and Su-27 differ under identical commands in roll response and takeoff")
 var unique: Dictionary={}
 for row: Dictionary in measurements:unique[str(snappedf(row.bank_after_1s_rad,0.001))]=true
 check(unique.size()==6,"six different measured roll responses, not display-only stats")
 var profiles: Array[Dictionary]=[]
 for profile: int in 3:
  var state: Dictionary=airborne(3,80);state.profile=profile;state.roll=.6;state.pitch=.3
  for i: int in 30:state=AviaFlight.step(state,AviaFlight.neutral())
  profiles.append(state)
 check(absf(profiles[0].roll)<absf(profiles[1].roll) and absf(profiles[1].roll)<absf(profiles[2].roll),"Arcade, Realistic and Expert have distinct neutral bank assistance")
 var tiny: Dictionary=airborne(3);tiny.profile=2
 var tiny_input: Dictionary=AviaFlight.neutral();tiny_input.roll=.01
 for i: int in 30:tiny=AviaFlight.step(tiny,tiny_input)
 check(absf(float(tiny.roll))>0.001,"small analog input accumulates angular response without quantization dead zone")
 var bad: Dictionary=AviaFlight.neutral();bad.profile=2
 check(not AviaFlight.valid_input(bad),"client cannot change server assistance category through input")
 print(JSON.stringify({"event":"fighter_comparison","status":"FAIL" if failed else "PASS","checks":checks,"measurements":measurements,"scope":"actual shared 30Hz Godot simulation; takeoff/landing fixtures are scripted, not human/device/model acceptance"}))
 quit(1 if failed else 0)
