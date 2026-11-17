extends SceneTree
## Actual candidate fit/rigid motion and shared flap forces; no type/device acceptance.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Flap check needs actual renderer");quit(2);return
 var model: AviaAircraft=AviaAircraft.build(3);root.add_child(model);model.set_process(false)
 var state: Dictionary=AviaFlight.spawn(3);var original: Dictionary=state.duplicate(true);model.update_state(state)
 check(state==original,"visual consumes authoritative state without mutating simulation")
 check(model.flap_instances!=null and model.flap_instances.multimesh.instance_count==2 and model.flap_deployment==0,"one configured mirrored pair at closed first snapshot")
 var cfg: Dictionary=AviaFlight.PLANES[3].visual.flap_animation
 var before: Array[Transform3D]=[]
 for i: int in 2:before.append(model.flap_instances.multimesh.get_instance_transform(i))
 # Hinge endpoints lie within the actual imported wing planform, upper skin within5cm.
 var fit: bool=true
 for i: int in 2:
  for t: float in [0,.5,1]:
   var at: Vector3=before[i]*Vector3(float(cfg.span_m)*t,0,float(cfg.hinge_sweep_m)*t)
   var top: float=-99
   for mesh: Node in model.get_node("AIModel").find_children("*","MeshInstance3D",true,false):
    if not str(mesh.name).begins_with("LOD0"):continue
    var tr: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
    for si: int in mesh.mesh.get_surface_count():
     var a: Array=mesh.mesh.surface_get_arrays(si);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX]
     for j: int in range(0,ix.size(),3):
      var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(at.x,5,at.z),Vector3(at.x,-5,at.z),tr*v[ix[j]],tr*v[ix[j+1]],tr*v[ix[j+2]])
      if hit!=null:top=maxf(top,hit.y)
   fit=fit and top>-98 and absf(at.y-top)<.05
 check(fit,"both hinge lines fit actual imported upper wing within5cm at six samples")
 var arrays: Array=model.flap_instances.multimesh.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var good: bool=true
 for i: int in range(0,vertices.size(),3):good=good and vertices[i].is_finite() and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()>1e-8
 for normal: Vector3 in normals:good=good and normal.is_finite() and normal.is_normalized()
 check(good and vertices.size()==36 and model.flap_instances.visibility_range_end==500,"one finite twelve-triangle mesh instanced twice, capped500m")
 state.flaps=true;model.update_state(state)
 check(model.flap_target==1 and model.flap_deployment==0,"subsequent authoritative deployment animates without snapping")
 model.advance_flaps(model.flap_duration*.5)
 check(is_equal_approx(model.flap_deployment,.5),"half travel uses constant elapsed time")
 var symmetric: bool=true;var rigid: bool=true;var down: bool=true
 for i: int in 2:
  var tr: Transform3D=model.flap_instances.multimesh.get_instance_transform(i)
  rigid=rigid and absf(absf(tr.basis.determinant())-1)<.00001 and tr.origin.is_equal_approx(before[i].origin)
  var tip: Vector3=tr*Vector3(0,0,float(cfg.chord_m));down=down and tip.y<tr.origin.y-.1
  var h: Vector3=Vector3(float(cfg.span_m),0,float(cfg.hinge_sweep_m))
  rigid=rigid and (tr*h).is_equal_approx(before[i]*h)
  for v: Vector3 in vertices:
   var left: Vector3=model.flap_instances.multimesh.get_instance_transform(0)*v;var right: Vector3=model.flap_instances.multimesh.get_instance_transform(1)*v
   symmetric=symmetric and Vector3(-left.x,left.y,left.z).is_equal_approx(right)
 check(rigid,"intermediate transforms remain rigid and hinge endpoints fixed")
 check(down and symmetric,"both trailing edges move down with exact mirror symmetry")
 for i: int in 10:model.update_state(state)
 model.advance_flaps(-1);check(is_equal_approx(model.flap_deployment,.5),"repeated snapshots/negative delta never restart or reverse progress")
 state.flaps=false;model.update_state(state);model.advance_flaps(model.flap_duration*.25)
 check(is_equal_approx(model.flap_deployment,.25),"mid-travel reversal is continuous")
 model.advance_flaps(1)
 check(model.flap_deployment==0 and model.flap_instances.multimesh.get_instance_transform(0).is_equal_approx(before[0]),"closed endpoint restores exact neutral transform")
 state.flaps=true;model.update_state(state)
 for i: int in 120:model.advance_flaps(model.flap_duration/120)
 check(is_equal_approx(model.flap_deployment,1),"120small steps reach same deployed endpoint")
 var late: AviaAircraft=AviaAircraft.build(3);root.add_child(late);late.set_process(false);late.update_state(state)
 check(late.flap_deployment==1,"late join baseline starts at replicated deployed state")
 late.free();state.crashed=true;model.update_state(state);model.advance_flaps(2)
 check(model.flap_deployment==0,"crash returns to neutral")
 for index: int in [0,4,5,6,7,8]:
  var untouched: AviaAircraft=AviaAircraft.build(index);check(untouched.flap_instances==null,AviaFlight.PLANES[index].aircraft_id+": no generic added surfaces");untouched.free()
 # Existing shared forces already implement flaps; verify visual addition preserves that effect.
 var dry: Dictionary=AviaFlight.spawn(3);dry.p=Vector3(0,500,0);dry.v=Vector3(0,0,-70);dry.grounded=false;dry.was_airborne=true;dry.gear=false;dry.profile=2
 var deployed: Dictionary=dry.duplicate(true);var c: Dictionary=AviaFlight.neutral();c.gear=false;c.throttle=0
 dry=AviaFlight.step(dry,c);c.flaps=true;deployed=AviaFlight.step(deployed,c)
 check(deployed.flaps and deployed.v.y>dry.v.y and absf(deployed.v.z)<absf(dry.v.z),"authoritative shared flap command adds actual lift and drag")
 var out: String=OS.get_environment("AVIA_FLAP_CAPTURE_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1000,760)
  var env: WorldEnvironment=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("8aa5b1");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;root.add_child(env)
  var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);root.add_child(sun)
  var camera: Camera3D=Camera3D.new();root.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13
  state=AviaFlight.spawn(3);state.gear=false;model.update_state(state);model.advance_gear(2)
  for stage: int in 3:
   if stage>0:state.flaps=true;model.update_state(state);model.advance_flaps(model.flap_duration*.5)
   for angle: int in 2:
    camera.size=13 if angle==0 else 5
    camera.position=Vector3(11,7,9) if angle==0 else Vector3(9,2,8);camera.look_at(Vector3(0,0,1) if angle==0 else Vector3(2.2,.2,2.7))
    await process_frame;await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(out.path_join("f16c-%d-%d.png"%[stage,angle]))==OK,"render stage%d view%d"%[stage,angle])
 var ok: bool=checks.all(func(row: Dictionary):return row.ok)
 var result: Dictionary={"event":"flap_summary","status":"PASS" if ok else "FAIL","checks":checks,"scope":"provisional authored F16C add-on flap pair, static AI wing retained; type-correct surfaces, recognition, phone and full aircraft acceptance pending"}
 if not out.is_empty():var f: FileAccess=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print(JSON.stringify(result));quit(0 if ok else 1)
