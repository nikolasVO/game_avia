extends Node2D
## Isolated engine/AVD diagnostic, never game or phone acceptance.
var frames: int=0
var draws: int=0
var physics: int=0
var reported_ms: int=0
var mode: String="2d"
var cube: MeshInstance3D
func _ready() -> void:
 var settings: ConfigFile=ConfigFile.new()
 if settings.load("user://surface.cfg")==OK:mode=str(settings.get_value("test","mode","2d"))
 if mode=="3d":
  var world: Node3D=Node3D.new();add_child(world)
  cube=MeshInstance3D.new();cube.mesh=BoxMesh.new()
  var mat: StandardMaterial3D=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX;mat.albedo_color=Color("e4bc75");cube.material_override=mat;world.add_child(cube)
  var light: DirectionalLight3D=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
  var camera: Camera3D=Camera3D.new();camera.position=Vector3(0,1,4);world.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
 RenderingServer.frame_post_draw.connect(func():draws+=1)
 print(JSON.stringify({"event":"surface_ready","engine":Engine.get_version_info(),"mode":mode,"thread_model":ProjectSettings.get_setting("rendering/driver/threads/thread_model"),"renderer":RenderingServer.get_current_rendering_method()}))
func _physics_process(_delta: float) -> void:physics+=1
func _process(delta: float) -> void:
 frames+=1
 if cube:cube.rotate_y(delta)
 queue_redraw()
 if Time.get_ticks_msec()-reported_ms>=1000:
  reported_ms=Time.get_ticks_msec()
  print(JSON.stringify({"event":"surface_frame","mode":mode,"frames":frames,"draws":draws,"physics":physics,"ticks_ms":reported_ms}))
func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_FOCUS_OUT]:
  print(JSON.stringify({"event":"surface_lifecycle","notification":what,"frames":frames,"draws":draws,"ticks_ms":Time.get_ticks_msec()}))
func _draw() -> void:
 draw_circle(Vector2(640+sin(frames*.04)*260,280),65,Color("e4bc75"))
 draw_string(ThemeDB.fallback_font,Vector2(100,100),"SURFACE QA · "+mode+" · frame "+str(frames),HORIZONTAL_ALIGNMENT_LEFT,-1,38,Color.WHITE)
