extends SceneTree
var reports: Array[Dictionary]=[]
var valid: bool=true
func visit(node: Node,totals: Dictionary,rows: Array[Dictionary]) -> void:
 if (node is MeshInstance3D or node is MultiMeshInstance3D) and node.visible:
  var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
  var instances: int=1 if node is MeshInstance3D else node.multimesh.instance_count
  if node is MultiMeshInstance3D:
   for i: int in instances:valid=valid and node.multimesh.get_instance_transform(i).is_finite()
  var count_tri: int=0
  var degenerate: int=0
  var minimum_area: float=INF
  for surface: int in mesh.get_surface_count():
   var material: Material=node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override else mesh.surface_get_material(surface)
   if material:totals.material_ids[material.get_instance_id()]=true
   var arrays: Array=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   var count: int=indices.size() if not indices.is_empty() else vertices.size()
   count_tri+=count/3;totals.surfaces+=1
   for v: Vector3 in vertices:valid=valid and v.is_finite()
   for i: int in range(0,count,3):
    var a: Vector3=vertices[indices[i] if not indices.is_empty() else i];var b: Vector3=vertices[indices[i+1] if not indices.is_empty() else i+1];var c: Vector3=vertices[indices[i+2] if not indices.is_empty() else i+2]
    var area: float=(b-a).cross(c-a).length()*.5
    minimum_area=minf(minimum_area,area)
    if area<=1e-12:degenerate+=1
    valid=valid and area>1e-12
  count_tri*=instances
  totals.triangles+=count_tri
  var level: int=0 if node.visibility_range_begin==0 else 1 if node.visibility_range_begin<800 else 2
  totals.lods[level]+=count_tri
  rows.append({"mesh":str(node.name),"level":level,"triangles":count_tri,"instances":instances,"degenerate_triangles":degenerate,"minimum_triangle_area_m2":minimum_area,"near_m":node.visibility_range_begin,"far_m":node.visibility_range_end})
 for child: Node in node.get_children():visit(child,totals,rows)
func _initialize() -> void:
 for index: int in range(3,9):
  var model: AviaAircraft=AviaAircraft.build(index);root.add_child(model)
  var totals: Dictionary={"triangles":0,"surfaces":0,"lods":[0,0,0],"material_ids":{}};var rows: Array[Dictionary]=[];visit(model,totals,rows)
  for level: int in 3:valid=valid and totals.lods[level]>0 and totals.lods[level]<=[20000,7000,2000][level]
  valid=valid and model.landing_gear.get_child_count()==4 and model.gear_instances.multimesh.instance_count==3 and model.gear_legs.size()==3 and model.exhaust.get_child_count()==int(AviaFlight.PLANES[index].geometry.engines)
  totals.unique_materials=totals.material_ids.size();totals.erase("material_ids");valid=valid and totals.unique_materials<=3
  var vectoring_check: bool=true
  if bool(AviaFlight.PLANES[index].get("visual",{}).get("nozzle_repair",false)):
   vectoring_check=model.vectoring_nozzles.size()==int(AviaFlight.PLANES[index].geometry.engines)
   var sample: Dictionary={"gear":true,"afterburner":false,"crashed":false,"v":Vector3.ZERO,"rates":Vector3(1,.5,0)}
   model.update_state(sample)
   for nozzle: Node3D in model.vectoring_nozzles:vectoring_check=vectoring_check and absf(nozzle.rotation.x)>0.05 and absf(nozzle.rotation.x)<=0.22 and absf(nozzle.rotation.y)<=0.16
   sample.v=Vector3(0,0,300);model.update_state(sample)
   for nozzle: Node3D in model.vectoring_nozzles:vectoring_check=vectoring_check and nozzle.rotation.is_equal_approx(Vector3.ZERO)
   valid=valid and vectoring_check
  reports.append({"aircraft_id":AviaFlight.PLANES[index].aircraft_id,"source":model.airframe_source,"low_speed_nozzle_cue_checked":bool(AviaFlight.PLANES[index].get("visual",{}).get("nozzle_repair",false)),"geometry":totals,"meshes":rows})
  model.free()
 print(JSON.stringify({"event":"fighter_geometry","status":"PASS" if valid else "FAIL","reports":reports,"scope":"finite nondegenerate meshes, per-LOD budgets including procedural gear/effects, engine count; recognition/art/mobile acceptance NOT VERIFIED"}))
 quit(0 if valid else 1)
