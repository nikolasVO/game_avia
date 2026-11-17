extends SceneTree
## Real aircraft nodes and flags; synthetic snapshot edges, no acceptance claim.
var checks: Array[Dictionary]=[]
var reports: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name()=="headless":
  push_error("Aircraft systems check requires a renderer for actual MultiMesh transforms");quit(1);return
 for index: int in range(3,9):
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model);model.set_process(false)
  var state: Dictionary=AviaFlight.spawn(index);model.update_state(state)
  var id: String=AviaFlight.PLANES[index].aircraft_id
  check(model.gear_legs.size()==3 and model.gear_instances.multimesh.instance_count==3 and model.landing_gear.visible and is_equal_approx(model.gear_deployment,1.0),id+": three deployed landing-gear legs")
  var anchors: Array[Vector3]=[]
  for leg: Node3D in model.gear_legs:anchors.append(leg.position)
  state.gear=false;model.update_state(state)
  check(model.landing_gear.visible and is_equal_approx(model.gear_deployment,1.0),id+": changing replicated flag does not instantly hide gear")
  model.advance_gear(model.gear_duration*0.5)
  check(is_equal_approx(model.gear_deployment,0.5) and model.landing_gear.visible and model.gear_legs[0].rotation.x<-.7 and model.gear_legs[1].rotation.z>.7 and model.gear_legs[2].rotation.z<-.7,id+": nose folds aft, main legs fold inward at half travel")
  var continuous: bool=true
  for i: int in anchors.size():
   var transform: Transform3D=model.gear_instances.multimesh.get_instance_transform(i)
   continuous=continuous and anchors[i].is_equal_approx(transform.origin) and transform.basis.is_equal_approx(model.gear_legs[i].basis)
  for repeat: int in 10:model.update_state(state)
  check(continuous and is_equal_approx(model.gear_deployment,0.5),id+": fixed attachment pivots and repeated snapshots preserve travel")
  state.gear=true;model.update_state(state);model.advance_gear(model.gear_duration*.25)
  check(is_equal_approx(model.gear_deployment,.75),id+": reversing flag reverses travel without snapping")
  model.advance_gear(model.gear_duration)
  check(is_equal_approx(model.gear_deployment,1) and model.gear_legs.all(func(leg: Node3D):return leg.rotation.is_zero_approx()),id+": gear returns to exact deployed endpoint")
  state.gear=false;model.update_state(state)
  for frame: int in 120:model.advance_gear(model.gear_duration/120.0)
  check(model.gear_deployment<0.0001 and not model.landing_gear.visible,id+": high-frame-rate retraction reaches hidden endpoint")
  # Late join with gear already raised never briefly deploys it.
  var late: AviaAircraft=AviaAircraft.build(index);root.add_child(late);late.set_process(false);late.update_state(state)
  check(is_zero_approx(late.gear_deployment) and not late.landing_gear.visible,id+": first airborne snapshot initializes retracted baseline")
  state.afterburner=true;model.update_state(state)
  check(model.exhaust.visible,id+": existing afterburner visual preserved")
  state.crashed=true;model.update_state(state)
  check(not model.exhaust.visible,id+": crash disables afterburner visual")
  reports.append({"aircraft_id":id,"gear_travel_seconds":model.gear_duration,"legs":3,"replicated_control":"existing gear flag, no protocol or simulation change","source":"authored strut/wheel assembly around existing candidate body"})
  model.free();late.free()
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"aircraft_systems","status":"PASS" if ok else "FAIL","checks":checks,"reports":reports,"scope":"real rendered model nodes and deterministic replicated-flag transitions; not physical/device/recognition acceptance"}))
 var directory: String=OS.get_environment("AVIA_SYSTEMS_CHECK_DIR")
 if ok and not directory.is_empty():await _capture(directory)
 quit(0 if ok else 1)

func _capture(directory: String) -> void:
 var world: Node3D=Node3D.new();root.add_child(world)
 var environment: WorldEnvironment=WorldEnvironment.new();var env: Environment=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("99b3bf");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8
 environment.environment=env;world.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-35,0);world.add_child(sun)
 var camera: Camera3D=Camera3D.new();world.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 for index: int in range(3,9):
  var model: AviaAircraft=AviaAircraft.build(index);world.add_child(model);model.set_process(false)
  var state: Dictionary=AviaFlight.spawn(index);model.update_state(state)
  var length: float=AviaFlight.PLANES[index].geometry.length_m;camera.size=length*1.12
  for stage: int in 3:
   if stage>0:state.gear=false;model.update_state(state);model.advance_gear(model.gear_duration*.5)
   for angle: int in 2:
    camera.position=Vector3(length*.65,-2.7,-length*.7) if angle==0 else Vector3(length*.8,-.2,-length*.05)
    camera.look_at(Vector3(0,-.3,0))
    await process_frame;await RenderingServer.frame_post_draw
    var name_: String="%s-%d-%d.png" % [AviaFlight.PLANES[index].aircraft_id,stage,angle]
    var result: int=root.get_texture().get_image().save_png(directory.path_join(name_))
    if result!=OK:push_error("Preview save failed: "+name_)
  model.free()
