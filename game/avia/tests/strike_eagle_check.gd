extends SceneTree
## Own provisional variant geometry and measured arcade-force differences.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func spec_for(id: String) -> Dictionary:
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id==id:
   var spec: Dictionary=row.duplicate(true);spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6;return spec
 return {}
func sample(speed: float) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(3);s.p=Vector3(0,1000,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true;s.gear=false;s.profile=2;return s
func vertices(model: AviaAircraft,name_: String) -> PackedVector3Array:
 return model.get_node(name_).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var before: String=JSON.stringify(AviaCatalog.all());var strike: Dictionary=spec_for("f15e");var eagle: Dictionary=spec_for("f15c")
 var model: AviaAircraft=AviaFighterVisual.create_spec(strike,false);root.add_child(model);model.set_process(false)
 check(not strike.playable and AviaCatalog.index_of("f15e")==-1 and AviaFlight.PLANES.size()==9,"planned variant keeps nine admitted prototypes")
 check(model.get_node_or_null("AIModel")==null and model.exhaust.get_child_count()==2 and model.gear_legs.size()==3,"own reference has paired engine exits and three gear legs without imported fallback")
 check(strike.geometry.fin_count==2 and strike.geometry.intake_layout=="side_pair" and not strike.systems.variable_sweep,"explicit paired vertical tails and side intakes; fixed wing")
 var canopy: Array=strike.geometry.canopy_sections_m
 check(float(canopy[-1][0])-float(canopy[0][0])>4.5 and float(strike.geometry.canopy_frame_z_m)>float(canopy[0][0]) and float(strike.geometry.canopy_frame_z_m)<float(canopy[-1][0]),"long tandem canopy has an authored dividing frame")
 var plain: Dictionary=strike.duplicate(true);plain.geometry.erase("conformal_tanks");plain.geometry.erase("canopy_frame_z_m")
 var control: AviaAircraft=AviaFighterVisual.create_spec(plain,false);root.add_child(control);control.set_process(false)
 var counts: Array[int]=[];var valid: bool=true;var mirrored: bool=true
 for name_: String in ["Airframe","LOD1","Distant"]:
  var points: PackedVector3Array=vertices(model,name_);counts.append(points.size()/3)
  var sides: int=8 if name_=="Airframe" else 6 if name_=="LOD1" else 4
  var expected: int=2*(8*sides+2*(sides-2))+(12 if name_!="Distant" else 0)
  check(points.size()-vertices(control,name_).size()==expected*3,"paired conformal shapes add explicit finite geometry at "+name_)
  var mesh: Array=model.get_node(name_).mesh.surface_get_arrays(0)
  for i: int in range(0,points.size(),3):valid=valid and points[i].is_finite() and (points[i+1]-points[i]).cross(points[i+2]-points[i]).length()>1e-9
  for normal: Vector3 in mesh[Mesh.ARRAY_NORMAL]:valid=valid and normal.is_finite() and normal.is_normalized()
  for p: Vector3 in points:
   var found: bool=false
   for q: Vector3 in points:
    if q.distance_to(Vector3(-p.x,p.y,p.z))<.0001:found=true;break
   mirrored=mirrored and found
 check(valid and mirrored,"all three authored LODs have finite nondegenerate symmetric geometry and normalized normals")
 check(counts[0]>counts[1] and counts[1]>counts[2] and counts[0]<20000 and counts[1]<7000 and counts[2]<2000,"decreasing supplied body LODs fit budgets")
 check(not eagle.geometry.has("conformal_tanks") and not eagle.geometry.has("canopy_frame_z_m"),"existing F15C reference remains distinct and unchanged")
 var values: Array[Dictionary]=[]
 for spec: Dictionary in [strike,eagle]:
  var c: Dictionary=AviaFlight.neutral();c.gear=false;c.throttle=.4;c.roll=.3
  var low: Dictionary=sample(90)
  for tick: int in 30:low=AviaFighter.step_spec(low,c,spec)
  var bank: float=absf(low.roll);var start: float=absf(low.rates.z);c.roll=0
  for tick: int in 10:low=AviaFighter.step_spec(low,c,spec)
  var residual: float=absf(low.rates.z)/start
  c=AviaFlight.neutral();c.gear=false;c.throttle=1
  var dry: Dictionary=sample(150);var boost: Dictionary=dry.duplicate(true)
  for tick: int in 120:
   dry=AviaFighter.step_spec(dry,c,spec);c.afterburner=true;boost=AviaFighter.step_spec(boost,c,spec);c.afterburner=false
  check(not dry.crashed and not boost.crashed and boost.v.length()>dry.v.length()+8,spec.aircraft_id+": afterburner affects actual acceleration")
  values.append({"aircraft_id":spec.aircraft_id,"low_speed_bank_rad":bank,"residual_roll_fraction":residual,"dry4s_mps":dry.v.length(),"boost4s_mps":boost.v.length()})
 check(values[0].low_speed_bank_rad<values[1].low_speed_bank_rad*.9,"strike variant responds more slowly to identical low-speed roll commands")
 check(values[0].residual_roll_fraction>values[1].residual_roll_fraction,"heavier strike variant retains more angular inertia after release")
 check(values[0].dry4s_mps<values[1].dry4s_mps-5 and values[0].boost4s_mps<values[1].boost4s_mps-8,"strike variant trades dry and boost acceleration for its stable heavy role")
 var command: Dictionary=AviaFlight.neutral();command.gear=false;command.throttle=.8;command.roll=.2
 var predicted: Dictionary=sample(160);var authority: Dictionary=predicted.duplicate(true)
 for tick: int in 90:predicted=AviaFighter.step_spec(predicted,command,strike);authority=AviaFighter.step_spec(authority,command,strike)
 check(predicted==authority and not predicted.crashed,"shared approved commands reproduce90ticks exactly")
 check(JSON.stringify(AviaCatalog.all())==before,"isolated variant checks preserve catalog and existing prototypes")
 var passed: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"strike_eagle_summary","status":"PASS" if passed else "FAIL","checks":checks,"body_lod_triangles":counts,"measurements":values,"scope":"own provisional reference and actual authored shared-force balance, no measured real variant geometry or human/network/phone/production acceptance"}))
 model.queue_free();control.queue_free();await process_frame;quit(0 if passed else 1)
