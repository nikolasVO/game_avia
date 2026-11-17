extends SceneTree
var target: String="/tmp/avia-ai-prop.png"
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):target=arg.trim_prefix("--out=")
 var scene: Node3D=Node3D.new();root.add_child(scene)
 var packed: PackedScene=load("res://assets/airfield_safety_block.glb")
 var prop: Node3D=AviaCatalogProp.build(packed);scene.add_child(prop)
 var rows: Array[Dictionary]=[];var ok: bool=true;var collider_hidden: bool=false
 for node: Node in prop.find_children("*","MeshInstance3D",true,false):
  var mesh: MeshInstance3D=node;var triangles: int=0;var valid: bool=true;var textures: Array[Vector2i]=[]
  for surface: int in range(mesh.mesh.get_surface_count()):
   var arrays: Array=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   triangles+=indices.size()/3 if indices.size()>0 else vertices.size()/3
   for vertex: Vector3 in vertices:valid=valid and vertex.is_finite()
   for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:valid=valid and normal.is_finite() and normal.length_squared()>0.5
   if arrays[Mesh.ARRAY_TEX_UV]!=null:
    for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:valid=valid and uv.is_finite()
   var material: Material=mesh.get_active_material(surface)
   if material is BaseMaterial3D:
    for slot: int in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:
     var texture: Texture2D=material.get_texture(slot)
     if texture:
      textures.append(Vector2i(texture.get_width(),texture.get_height()));valid=valid and texture.get_width()<=1024 and texture.get_height()<=1024
  var bounds: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  if str(node.name).begins_with("COLLISION"):collider_hidden=not mesh.visible
  else:ok=ok and valid and triangles<=5000 and absf(bounds.position.y)<0.02 and bounds.size.distance_to(Vector3.ONE)<0.02
  rows.append({"name":str(node.name),"triangles":triangles,"valid_vertices_normals_uv_texture_budget":valid,"visible":mesh.visible,"bounds_position":str(bounds.position),"bounds_size":str(bounds.size),"ranges":[mesh.visibility_range_begin,mesh.visibility_range_end],"texture_sizes":textures})
 ok=ok and collider_hidden and rows.size()==4
 print(JSON.stringify({"event":"catalog_import","status":"PASS" if ok else "FAIL","source_type":"AI/TRELLIS from preserved existing AI reference","meshes":rows,"authoring_collider_hidden":collider_hidden,"scope":"Actual GLB import/runtime configuration, not an AI aircraft or physics collision claim"}))
 if not ok:quit(1);return
 if DisplayServer.get_name()=="headless":quit();return
 var environment: WorldEnvironment=WorldEnvironment.new();var env: Environment=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("91b5c6");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=0.7;environment.environment=env;scene.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);scene.add_child(sun)
 var camera: Camera3D=Camera3D.new();scene.add_child(camera);camera.position=Vector3(1.8,1.5,-2.8);camera.look_at(Vector3(0,0.5,0));camera.fov=40;camera.current=true
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(target)
 quit()
