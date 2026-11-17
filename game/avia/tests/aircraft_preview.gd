extends SceneTree
var world: Node3D
var camera: Camera3D
var frames: int=0
var destination: String="/tmp/game-avia-aircraft.png"
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):destination=arg.trim_prefix("--out=")
 world=Node3D.new();root.add_child(world)
 var environment: WorldEnvironment=WorldEnvironment.new();var env: Environment=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("91b5c6");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=0.7;environment.environment=env;world.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);world.add_child(sun)
 var reports: Array[Dictionary]=[]
 for index: int in range(3):
  var plane: AviaAircraft=AviaAircraft.build(index);plane.position.x=(index-1)*18;world.add_child(plane);plane.set_process(false)
  var meshes: Array[Dictionary]=[]
  for name_: String in ["Airframe","Distant","Propeller/Blades"]:
   var node: MeshInstance3D=plane.get_node_or_null(name_)
   if node==null:continue
   var arrays: Array=node.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var valid: bool=true
   for v: Vector3 in vertices:valid=valid and v.is_finite()
   for i: int in range(0,vertices.size(),3):valid=valid and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()>0.0000001
   meshes.append({"name":name_,"triangles":vertices.size()/3,"materials":1,"aabb_position":str(node.mesh.get_aabb().position),"aabb_size":str(node.mesh.get_aabb().size),"finite_nondegenerate":valid,"visibility_m":[node.visibility_range_begin,node.visibility_range_end]})
  reports.append({"plane":index,"name":AviaFlight.PLANES[index].name,"meshes":meshes})
 var valid: bool=reports.all(func(r: Dictionary):return r.meshes.all(func(m: Dictionary):return m.finite_nondegenerate))
 print(JSON.stringify({"status":"PASS" if valid else "FAIL","event":"procedural_geometry","source_type":"procedural","planes":reports}))
 camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(24,25,-39);camera.look_at(Vector3.ZERO);camera.current=true;camera.fov=48
 if not valid:quit(1);return
 if DisplayServer.get_name()=="headless":quit();return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(destination)
 quit()
