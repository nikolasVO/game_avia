extends SceneTree
## Free project-authored single-view reference + separate QC views. No image API or collage.
var destination: String="/tmp/avia-fighter-reference"
var index: int=3
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):destination=arg.trim_prefix("--out=")
  if arg.begins_with("--plane="):index=int(arg.trim_prefix("--plane="))
 root.size=Vector2i(1024,1024);root.content_scale_size=Vector2i(1024,1024);root.transparent_bg=true
 DirAccess.make_dir_recursive_absolute(destination)
 var world: Node3D=Node3D.new();root.add_child(world)
 var environment: WorldEnvironment=WorldEnvironment.new();var env: Environment=Environment.new();env.background_mode=Environment.BG_CLEAR_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;environment.environment=env;world.add_child(environment);RenderingServer.set_default_clear_color(Color(0,0,0,0))
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);world.add_child(sun)
 var model: AviaAircraft=AviaAircraft.build(index);world.add_child(model)
 if model.landing_gear:model.landing_gear.hide()
 var camera: Camera3D=Camera3D.new();world.add_child(camera);camera.fov=40;camera.current=true
 var length: float=float(AviaFlight.PLANES[index].geometry.length_m)
 var views: Dictionary={"reference":Vector3(.85,.6,-1.25)*length,"top":Vector3(0,1.8,0)*length,"front":Vector3(0,.08,-1.8)*length,"side":Vector3(1.8,.08,0)*length}
 var files: Dictionary={}
 for name_: String in views:
  camera.position=views[name_];camera.look_at(Vector3.ZERO,Vector3.FORWARD if name_=="top" else Vector3.UP)
  await process_frame;await RenderingServer.frame_post_draw
  var picture: Image=root.get_texture().get_image()
  if picture.get_width()!=1024 or picture.get_height()!=1024:push_error("reference_size_mismatch");quit(1);return
  var path: String=destination+"/"+name_+".png"
  if picture.save_png(path)!=OK:quit(1);return
  var hash_: HashingContext=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(FileAccess.get_file_as_bytes(path));files[name_+".png"]={"sha256":hash_.finish().hex_encode(),"width":1024,"height":1024}
 var manifest: Dictionary={"aircraft_id":AviaFlight.PLANES[index].aircraft_id,"source_type":"procedural_reference","generator":"game/avia/tests/fighter_reference.gd and client/fighter_visual.gd","input_view":"reference.png","qc_views_only":["top.png","front.png","side.png"],"conditioning":"single reference.png only, never the QC views as a collage","description":"Own approximate game fighter geometry, no logos/insignia or copied third-party model; variant recognition/proportions require further review","paid_calls":0,"files":files}
 var file: FileAccess=FileAccess.open(destination+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
 print(JSON.stringify({"event":"fighter_reference","status":"PASS","manifest":manifest}))
 quit()
