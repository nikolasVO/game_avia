extends SceneTree
var reports: Array[Dictionary]=[]
var valid: bool=true
func visit(node: Node,totals: Dictionary,rows: Array[Dictionary]) -> void:
 if node is MeshInstance3D and node.visible:
  var mesh: Mesh=node.mesh
  var count_tri: int=0
  for surface: int in mesh.get_surface_count():
   var material: Material=node.get_active_material(surface)
   if material:totals.material_ids[material.get_instance_id()]=true
   var arrays: Array=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   var count: int=indices.size() if not indices.is_empty() else vertices.size()
   count_tri+=count/3;totals.surfaces+=1
   for v: Vector3 in vertices:valid=valid and v.is_finite()
   for i: int in range(0,count,3):
    var a: Vector3=vertices[indices[i] if not indices.is_empty() else i];var b: Vector3=vertices[indices[i+1] if not indices.is_empty() else i+1];var c: Vector3=vertices[indices[i+2] if not indices.is_empty() else i+2]
    valid=valid and (b-a).cross(c-a).length()*.5>1e-12
  totals.triangles+=count_tri
  var level: int=0 if node.visibility_range_begin==0 else 1 if node.visibility_range_begin<800 else 2
  totals.lods[level]+=count_tri
  rows.append({"mesh":str(node.name),"level":level,"triangles":count_tri,"near_m":node.visibility_range_begin,"far_m":node.visibility_range_end})
 for child: Node in node.get_children():visit(child,totals,rows)
func _initialize() -> void:
 for index: int in range(3,9):
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model)
  var totals: Dictionary={"triangles":0,"surfaces":0,"lods":[0,0,0],"material_ids":{}};var rows: Array[Dictionary]=[];visit(model,totals,rows)
  for level: int in 3:valid=valid and totals.lods[level]>0 and totals.lods[level]<=[20000,7000,2000][level]
  valid=valid and model.landing_gear.get_child_count()==1 and model.exhaust.get_child_count()==int(AviaFlight.PLANES[index].geometry.engines)
  totals.unique_materials=totals.material_ids.size();totals.erase("material_ids");valid=valid and totals.unique_materials<=3
  reports.append({"aircraft_id":AviaFlight.PLANES[index].aircraft_id,"source":model.airframe_source,"geometry":totals,"meshes":rows})
  model.free()
 print(JSON.stringify({"event":"fighter_geometry","status":"PASS" if valid else "FAIL","reports":reports,"scope":"finite nondegenerate meshes, per-LOD budgets including procedural gear/effects, engine count; recognition/art/mobile acceptance NOT VERIFIED"}))
 quit(0 if valid else 1)
