extends SceneTree
## Own provisional Tornado-style geometry and actual sweep forces, planned only.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func sample(speed: float) -> Dictionary:
 var s: Dictionary=AviaFlight.spawn(3);s.p=Vector3(0,1000,0);s.v=Vector3(0,0,-speed);s.grounded=false;s.was_airborne=true;s.gear=false;s.profile=2;return s
func panel_points(model: AviaAircraft) -> Array[Vector3]:
 var points: Array[Vector3]=[]
 for node: Node in model.find_children("PanelLOD0","MeshInstance3D",true,false):
  for p: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:points.append(model.global_transform.affine_inverse()*node.global_transform*p)
 return points
func box(points: Array[Vector3]) -> AABB:
 var result: AABB=AABB(points[0],Vector3.ZERO)
 for p: Vector3 in points:result=result.expand(p)
 return result
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var before: String=JSON.stringify(AviaCatalog.all());var spec: Dictionary={};var f14: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="tornado":spec=row.duplicate(true)
  if row.aircraft_id=="f14":f14=row
 spec.stall=float(spec.flight.stall_speed_kmh)/3.6;spec.max=float(spec.flight.max_speed_altitude_kmh)/3.6
 check(not spec.playable and AviaCatalog.index_of("tornado")==-1 and AviaFlight.PLANES.size()==9,"planned strike type preserves nine admitted prototypes")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec,false);root.add_child(model);model.set_process(false)
 check(model.get_node_or_null("AIModel")==null and spec.geometry.fin_count==1 and model.exhaust.get_child_count()==2,"own single-fin/two-engine geometry, no imported fallback")
 check(spec.geometry.canopy_sections_m[2][0]-spec.geometry.canopy_sections_m[0][0]>2.5 and spec.geometry.intake_layout=="side_pair","long tandem canopy and paired side intakes")
 check(model.sweep_wings.size()==2 and model.sweep_wings[0].get_child_count()==3,"two pivoted panels with three LOD tiers each")
 var open: AABB=box(panel_points(model));model.pose_sweep(1);var closed: AABB=box(panel_points(model))
 check(absf(open.size.x-13.9)<.01 and closed.size.x<open.size.x*.80 and closed.end.z>open.end.z+1.5,"actual panel span decreases and tips move aft across42degree sweep")
 var mirrored: bool=true
 for fraction: float in [0,.25,.5,.75,1]:
  model.pose_sweep(fraction);var points: Array[Vector3]=panel_points(model)
  for p: Vector3 in points:
   var found: bool=false
   for q: Vector3 in points:
    if q.distance_to(Vector3(-p.x,p.y,p.z))<.0001:found=true;break
   mirrored=mirrored and found
 check(mirrored,"both panels stay exactly mirrored through five travel positions")
 var counts: Array[int]=[];var finite: bool=true
 for name_: String in ["Airframe","LOD1","Distant"]:
  var mesh: MeshInstance3D=model.get_node(name_);var a: Array=mesh.mesh.surface_get_arrays(0);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL];counts.append(v.size()/3)
  for i: int in range(0,v.size(),3):finite=finite and v[i].is_finite() and (v[i+1]-v[i]).cross(v[i+2]-v[i]).length()>1e-9
  for n: Vector3 in normals:finite=finite and n.is_finite() and n.is_normalized()
 check(finite and counts[0]>counts[1] and counts[1]>counts[2],"three finite nondegenerate body LODs with normalized normals")
 check(spec.geometry.length_m<f14.geometry.length_m and spec.geometry.fin_count==1 and spec.sweep.travel_degrees!=f14.sweep.travel_degrees,"strike reference differs from large twin-fin F14 geometry and travel")
 check(AviaFighter.sweep_fraction(spec,165,false,false)==0 and AviaFighter.sweep_fraction(spec,240,false,false)==.5 and AviaFighter.sweep_fraction(spec,315,false,false)==1,"type-specific automatic sweep schedule exact boundaries")
 check(AviaFighter.sweep_fraction(spec,500,true,false)==0 and AviaFighter.sweep_fraction(spec,500,false,true)==0,"gear and flap interlocks open wings")
 var unswept: Dictionary=spec.duplicate(true);unswept.systems.variable_sweep=false
 var c: Dictionary=AviaFlight.neutral();c.gear=false;c.throttle=1;c.roll=.5
 var low_sweep: Dictionary=AviaFighter.step_spec(sample(150),c,spec);var low_unswept: Dictionary=AviaFighter.step_spec(sample(150),c,unswept)
 check(low_sweep.v==low_unswept.v and low_sweep.rates==low_unswept.rates,"open low-speed wings preserve unswept forces exactly")
 var fast: Dictionary=sample(340);var swept: Dictionary=AviaFighter.step_spec(fast,c,spec);var extended: Dictionary=AviaFighter.step_spec(fast,c,unswept)
 check(swept.v.z<extended.v.z and absf(swept.rates.z)<absf(extended.rates.z),"swept wings reduce actual drag and control response")
 var lift_spec: Dictionary=spec.duplicate(true);lift_spec.sweep.start_speed_kmh=100;lift_spec.sweep.full_speed_kmh=200
 var low: Dictionary=sample(90);var lifted: Dictionary=AviaFighter.step_spec(low,c,lift_spec);var low_open: Dictionary=AviaFighter.step_spec(low,c,unswept)
 check(lifted.v.y<low_open.v.y-.01,"swept lift ratio affects vertical acceleration below clamp")
 var predicted: Dictionary=fast.duplicate(true);var authority: Dictionary=fast.duplicate(true)
 for tick: int in 60:predicted=AviaFighter.step_spec(predicted,c,spec);authority=AviaFighter.step_spec(authority,c,spec)
 check(predicted==authority and not authority.crashed,"same shared fixed-step forces reproduce60ticks exactly")
 model.pose_sweep(0);model.sweep_initialized=false
 var state: Dictionary={"v":Vector3(0,0,-400),"gear":false,"flaps":false,"crashed":false,"afterburner":false}
 model.update_state(state);check(model.sweep_fraction==1,"first snapshot establishes high-speed sweep baseline")
 state.gear=true;model.update_state(state);model._process(1.25);check(is_equal_approx(model.sweep_fraction,.5),"gear interlock animates bounded half travel")
 state.gear=false;model.update_state(state);model._process(.625);check(is_equal_approx(model.sweep_fraction,.75),"mid-travel reversal stays continuous")
 check(JSON.stringify(AviaCatalog.all())==before,"geometry and force tests preserve catalog")
 var out: String=OS.get_environment("AVIA_STRIKE_CAPTURE_DIR")
 if not out.is_empty():
  if DisplayServer.get_name()=="headless":push_error("actual renderer required for captures");quit(2);return
  DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1000,760)
  var env: WorldEnvironment=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("536c79");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;root.add_child(env)
  var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);root.add_child(sun)
  var camera: Camera3D=Camera3D.new();root.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=22
  model.landing_gear.hide()
  for stage: int in 3:
   model.pose_sweep(stage*.5)
   for view: int in 2:
    camera.position=Vector3(15,10,-19) if view==0 else Vector3(0,30,0);camera.look_at(Vector3.ZERO,Vector3.UP if view==0 else Vector3.FORWARD)
    await process_frame;await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(out.path_join("tornado-%d-%d.png"%[stage,view]))==OK,"render sweep%d view%d"%[stage,view])
 var passed: bool=checks.all(func(c_: Dictionary):return c_.ok)
 var result: Dictionary={"status":"PASS" if passed else "FAIL","event":"strike_sweep_summary","checks":checks,"body_triangles":counts,"force_measurements":{"swept_forward_mps":-swept.v.z,"open_forward_mps":-extended.v.z,"swept_roll_rate":swept.rates.z,"open_roll_rate":extended.rates.z,"swept_vertical_mps":lifted.v.y,"open_vertical_mps":low_open.v.y},"open_span_m":open.size.x,"closed_span_m":closed.size.x,"production_accepted":false,"playable":false,"scope":"own provisional single-fin twin-engine strike reference and actual authored arcade sweep forces only; primary facts/recognition/AI/network/human/mobile/rights and15gates pending"}
 if not out.is_empty():var f: FileAccess=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print(JSON.stringify(result));quit(0 if passed else 1)
