extends SceneTree
var reports: Array[Dictionary]=[]
var valid: bool=true
func visit(node: Node,totals: Dictionary) -> void:
 if node is MeshInstance3D:
  var mesh: Mesh=node.mesh
  for surface: int in mesh.get_surface_count():
   var arrays: Array=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   var count: int=indices.size() if not indices.is_empty() else vertices.size()
   totals.triangles+=count/3;totals.surfaces+=1
   for v: Vector3 in vertices:valid=valid and v.is_finite()
   for i: int in range(0,count,3):
    var a: Vector3=vertices[indices[i] if not indices.is_empty() else i];var b: Vector3=vertices[indices[i+1] if not indices.is_empty() else i+1];var c: Vector3=vertices[indices[i+2] if not indices.is_empty() else i+2]
    valid=valid and (b-a).cross(c-a).length_squared()>0.00000001
 for child: Node in node.get_children():visit(child,totals)
func _initialize() -> void:
 for index: int in range(3,9):
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model)
  var totals: Dictionary={"triangles":0,"surfaces":0};visit(model,totals)
  var lods: Array[Dictionary]=[]
  for id: String in ["Airframe","LOD1","Distant"]:
   var mesh: MeshInstance3D=model.get_node(id)
   lods.append({"lod":id,"triangles":mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3,"aabb":str(mesh.mesh.get_aabb()),"near_m":mesh.visibility_range_begin,"far_m":mesh.visibility_range_end})
  valid=valid and totals.triangles<20000 and model.landing_gear.get_child_count()==1 and model.exhaust.get_child_count()==int(AviaFlight.PLANES[index].geometry.engines)
  reports.append({"aircraft_id":AviaFlight.PLANES[index].aircraft_id,"geometry":totals,"lods":lods})
  model.free()
 print(JSON.stringify({"event":"fighter_geometry","status":"PASS" if valid else "FAIL","source_type":"procedural_placeholder","reports":reports,"scope":"finite nondegenerate meshes, 3LOD ranges, engine effect count; recognition/art/mobile acceptance NOT VERIFIED"}))
 quit(0 if valid else 1)
