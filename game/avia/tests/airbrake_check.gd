extends SceneTree
## Authored panels around candidate bodies. Actual renderer, no aircraft/device acceptance.
var checks: Array[Dictionary]=[]
var budgets: Array[Dictionary]=[]
var directory: String=""
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func triangles(mesh: Mesh) -> int:
 var total: int=0
 for surface: int in mesh.get_surface_count():
  var a: Array=mesh.surface_get_arrays(surface);var indices: Variant=a[Mesh.ARRAY_INDEX]
  total+=(indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
 return total
func _initialize() -> void:_run.call_deferred()
func body_limits(model: AviaAircraft,at: Vector3) -> Vector2:
 var limits: Vector2=Vector2(99,-99)
 for mesh: Node in model.get_node("AIModel").find_children("*","MeshInstance3D",true,false):
  if not str(mesh.name).begins_with("LOD0"):continue
  var transform_: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
  for surface: int in mesh.mesh.get_surface_count():
   var a: Array=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX]
   for j: int in range(0,ix.size(),3):
    var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(at.x,8,at.z),Vector3(at.x,-8,at.z),transform_*vertices[ix[j]],transform_*vertices[ix[j+1]],transform_*vertices[ix[j+2]])
    if hit!=null:limits.x=minf(limits.x,hit.y);limits.y=maxf(limits.y,hit.y)
 return limits
func _run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Airbrake check requires actual renderer");quit(2);return
 directory=OS.get_environment("AVIA_AIRBRAKE_CAPTURE_DIR")
 root.size=Vector2i(900,700)
 for index: int in AviaFlight.PLANES.size():
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model);model.set_process(false)
  var state: Dictionary=AviaFlight.spawn(index);var original: Dictionary=state.duplicate(true);model.update_state(state)
  var id: String=AviaFlight.PLANES[index].aircraft_id
  if index not in [3,4,5]:
   check(model.airbrake_instances==null,id+": no invented generic panels on unconfigured type");model.free();continue
  check(model.airbrake_instances.multimesh.instance_count==([4,1,1][index-3]) and model.airbrake_deployment==0,id+": explicitly configured closed baseline")
  check(state==original,id+": visual reads state without changing physics")
  var neutral: Array[Transform3D]=[]
  for i: int in model.airbrake_hinges.size():neutral.append(model.airbrake_instances.multimesh.get_instance_transform(i))
  var config: Dictionary=AviaFlight.PLANES[index].visual.airbrake_animation
  var fit: bool=true
  for i: int in neutral.size():
   var midpoint: Vector3=neutral[i]*Vector3(0,0,float(config.size_m[2])*.5)
   var limits: Vector2=body_limits(model,midpoint)
   var surface_y: float=limits.y if model.airbrake_angles[i]<0 else limits.x
   fit=fit and limits.x<=limits.y and absf(midpoint.y-surface_y)<.13
  check(fit,id+": closed panels fit sampled actual imported upper/lower body within13cm")
  state.airbrake=true;model.update_state(state)
  check(model.airbrake_deployment==0 and model.airbrake_target==1,id+": replicated edge changes target without snapping")
  model.advance_airbrake(model.airbrake_duration*.5)
  var half_ok: bool=is_equal_approx(model.airbrake_deployment,.5)
  for i: int in neutral.size():
   var at: Transform3D=model.airbrake_instances.multimesh.get_instance_transform(i)
   half_ok=half_ok and at.origin.is_equal_approx(neutral[i].origin) and not at.basis.is_equal_approx(neutral[i].basis) and is_equal_approx(at.basis.determinant(),1)
   # Trailing edge rises for dorsal/top panels and lowers for lower split panels.
   var tip: Vector3=at*Vector3(0,0,1)
   half_ok=half_ok and signf(tip.y-at.origin.y)==-signf(model.airbrake_angles[i])
  check(half_ok,id+": intermediate rigid transform and correct hinge/trailing-edge direction")
  for repeat: int in 10:model.update_state(state)
  model.advance_airbrake(-1)
  check(is_equal_approx(model.airbrake_deployment,.5),id+": repeated snapshots and negative delta preserve travel")
  state.airbrake=false;model.update_state(state);model.advance_airbrake(model.airbrake_duration*.25)
  check(is_equal_approx(model.airbrake_deployment,.25),id+": reversal remains continuous")
  model.advance_airbrake(1)
  var closed: bool=model.airbrake_deployment==0
  for i: int in neutral.size():closed=closed and model.airbrake_instances.multimesh.get_instance_transform(i).is_equal_approx(neutral[i])
  check(closed,id+": exact closed endpoint")
  state.airbrake=true;model.update_state(state)
  for frame: int in 120:model.advance_airbrake(model.airbrake_duration/120.0)
  check(is_equal_approx(model.airbrake_deployment,1),id+": frame-rate independent open endpoint")
  var late: AviaAircraft=AviaAircraft.build(index);root.add_child(late);late.set_process(false);late.update_state(state)
  check(late.airbrake_deployment==1 and late.airbrake_target==1,id+": late airborne snapshot initializes correct baseline")
  state.crashed=true;model.update_state(state);model.advance_airbrake(1)
  check(model.airbrake_target==0 and model.airbrake_deployment==0,id+": crash returns panels to rest")
  check(triangles(model.airbrake_instances.multimesh.mesh)==12 and model.airbrake_instances.visibility_range_end==500,id+": one instanced twelve-triangle panel draw capped500m")
  late.free();model.free()
 # Count full assemblies including hidden gear/afterburner/airbrakes, all candidate LODs.
 for spec: Dictionary in AviaCatalog.all():
  if not spec.get("visual",{}).has("scene"):continue
  var model: AviaAircraft=AviaFighterVisual.create_spec(spec,true);root.add_child(model);model.set_process(false)
  for distance: int in [100,400,600,950]:
   var total: int=0
   for node: Node in model.find_children("*","GeometryInstance3D",true,false):
    if distance<node.visibility_range_begin or (node.visibility_range_end>0 and distance>=node.visibility_range_end):continue
    if node is MeshInstance3D:total+=triangles(node.mesh)
    elif node is MultiMeshInstance3D:total+=triangles(node.multimesh.mesh)*node.multimesh.instance_count
   var limit: int=20000 if distance<350 else 7000 if distance<900 else 2000
   check(total>0 and total<=limit,str(spec.aircraft_id)+": worst-case assembly budget at "+str(distance)+"m")
   budgets.append({"aircraft_id":spec.aircraft_id,"distance_m":distance,"triangles":total,"limit":limit})
  model.free()
 if not directory.is_empty():await capture()
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 var result: Dictionary={"event":"airbrake_summary","status":"PASS" if ok else "FAIL","checks":checks,"assembly_budgets":budgets,"scope":"rendered authored provisional panels on three existing candidates, not type-correct articulation or production/device acceptance"}
 if not directory.is_empty():
  var file: FileAccess=FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print(JSON.stringify(result));quit(0 if ok else 1)
func capture() -> void:
 var env: WorldEnvironment=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("8aa5b1");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;root.add_child(env)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);root.add_child(sun)
 var camera: Camera3D=Camera3D.new();root.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 for index: int in [3,4,5]:
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model);model.set_process(false)
  var state: Dictionary=AviaFlight.spawn(index);state.gear=false;model.update_state(state)
  var length: float=AviaFlight.PLANES[index].geometry.length_m;camera.size=length*1.06
  for stage: int in 3:
   if stage>0:state.airbrake=true;model.update_state(state);model.advance_airbrake(model.airbrake_duration*.5)
   for angle: int in 2:
    camera.position=Vector3(length*.7,length*.33,length*.55) if angle==0 else Vector3(length*.7,length*.07,-length*.05)
    camera.look_at(Vector3(0,0,0))
    await process_frame;await RenderingServer.frame_post_draw
    var file: String="%s-%d-%d.png" % [AviaFlight.PLANES[index].aircraft_id,stage,angle]
    check(root.get_texture().get_image().save_png(directory.path_join(file))==OK,"render "+file)
  model.free()
