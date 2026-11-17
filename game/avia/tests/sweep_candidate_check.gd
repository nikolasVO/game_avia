extends SceneTree
## Planned-only imported assembly QA; never admits a plane to public sessions.
var checks: Array[Dictionary]=[]
var valid: bool=true
var aircraft_id: String="f14"
var destination: String="/tmp/avia-sweep-candidate"
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"ok":ok});valid=valid and ok
func mesh_triangles(mesh: Mesh) -> int:
 var total: int=0
 for surface: int in mesh.get_surface_count():
  var arrays: Array=mesh.surface_get_arrays(surface);var indices: Variant=arrays[Mesh.ARRAY_INDEX]
  total+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 return total
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):destination=arg.trim_prefix("--out=")
  if arg.begins_with("--aircraft-id="):aircraft_id=arg.trim_prefix("--aircraft-id=")
 if DisplayServer.get_name()=="headless":
  push_error("Sweep candidate check requires an actual renderer");quit(2);return
 DirAccess.make_dir_recursive_absolute(destination)
 root.size=Vector2i(768,768);root.content_scale_size=Vector2i(768,768)
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id==aircraft_id:spec=row
 if spec.is_empty() or not spec.get("systems",{}).get("variable_sweep",false) or spec.get("visual",{}).get("articulated_lods",[]).size()!=3:
  push_error("Imported variable-sweep candidate required: "+aircraft_id);quit(1);return
 check(not spec.playable and AviaCatalog.index_of(aircraft_id)==-1 and AviaFlight.PLANES.size()==9,"planned candidate stays outside nine admitted aircraft")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec,true);root.add_child(model);model.set_process(false);model.landing_gear.hide()
 check(model.sweep_wings.size()==6,"six imported panels registered across three explicit LODs")
 check(mesh_triangles(model.gear_instances.multimesh.mesh)*model.gear_instances.multimesh.instance_count==72,"full assembly counter includes all three 24-triangle gear units")
 # Count every in-range draw, including fully deployed gear and lit afterburners.
 # This deliberate upper bound also includes hidden effects; no screenshot-only count.
 var assembly_budgets: Array[Dictionary]=[]
 for distance: int in [100,400,600,950]:
  var total: int=0;var parts: Dictionary={}
  for node: Node in model.find_children("*","GeometryInstance3D",true,false):
   if distance<node.visibility_range_begin or (node.visibility_range_end>0 and distance>=node.visibility_range_end):continue
   var triangles: int=0
   if node is MeshInstance3D:triangles=mesh_triangles(node.mesh)
   elif node is MultiMeshInstance3D:triangles=mesh_triangles(node.multimesh.mesh)*node.multimesh.instance_count
   total+=triangles;parts[str(model.get_path_to(node))]=triangles
  var budget: int=20000 if distance<350 else 7000 if distance<900 else 2000
  check(total>0 and total<=budget,"worst-case full assembly fits budget at "+str(distance)+"m including gear/afterburners")
  assembly_budgets.append({"distance_m":distance,"triangles":total,"budget":budget,"parts":parts})
 var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("202e3c")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;root.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);root.add_child(sun)
 var camera: Camera3D=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=27;camera.current=true
 var tiers: Array[Node]=model.get_node("AIModel").get_children();var counts: Array[int]=[];var images: Array[String]=[];var spans: Array[Dictionary]=[]
 if tiers.size()!=3:
  push_error("Expected three explicit candidate LODs");quit(1);return
 for level: int in 3:
  var vertices_ok: bool=true;var triangles: int=0;var panels: int=0;var bodies: int=0;var leftover: bool=false;var ranges_ok: bool=true
  for mesh: Node in tiers[level].find_children("*","MeshInstance3D",true,false):
   ranges_ok=ranges_ok and mesh.visibility_range_begin==[0,350,900][level] and mesh.visibility_range_end==[350,900,2500][level]
   mesh.visibility_range_begin=0;mesh.visibility_range_end=0
   if str(mesh.name).contains("Wing"):panels+=1
   else:bodies+=1
   for surface: int in mesh.mesh.get_surface_count():
    var arrays: Array=mesh.mesh.surface_get_arrays(surface);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:vertices_ok=vertices_ok and normal.is_finite()
    var count: int=indices.size() if not indices.is_empty() else points.size();triangles+=count/3
    for p: Vector3 in points:
     vertices_ok=vertices_ok and p.is_finite()
     var local: Vector3=model.global_transform.affine_inverse()*mesh.global_transform*p
     if not str(mesh.name).contains("Wing") and absf(local.x)>float(spec.geometry.sweep_pivot_x_m)+.002 and local.z<float(spec.visual.get("articulation_cut_z_m",4.8))-.002:leftover=true
    for j: int in range(0,count,3):
     var a: Vector3=points[indices[j] if not indices.is_empty() else j];var b: Vector3=points[indices[j+1] if not indices.is_empty() else j+1];var c: Vector3=points[indices[j+2] if not indices.is_empty() else j+2]
     vertices_ok=vertices_ok and (b-a).cross(c-a).length()*.5>1e-12
  check(vertices_ok and triangles<=[20000,7000,2000][level],"LOD"+str(level)+" imported triangles finite/nondegenerate and within budget")
  check(panels==2 and bodies==1 and not leftover,"LOD"+str(level)+" has two moving panels and no static wing duplicate")
  check(ranges_ok,"LOD"+str(level)+" body and both panels share exact explicit visibility range")
  var gloves: Array[Node]=model.find_children("PivotGloveLOD*","MeshInstance3D",true,false)
  check(gloves.size()==3,"three authored pivot-cover LODs present")
  for other: int in 3:
   gloves[other].visibility_range_begin=0;gloves[other].visibility_range_end=0;gloves[other].visible=other==level
  triangles+=gloves[level].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3
  check(triangles<=[20000,7000,2000][level],"LOD"+str(level)+" combined AI panels/body and authored gloves fit budget")
  counts.append(triangles)
  for other: int in 3:tiers[other].visible=other==level
  var open_span: float=0;var closed_span: float=0
  for pose: int in 3:
   model.pose_sweep(pose*.5)
   var box: AABB;var initialized: bool=false
   for mesh: Node in tiers[level].find_children("*Wing*","MeshInstance3D",true,false):
    for point: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
     var local: Vector3=model.global_transform.affine_inverse()*mesh.global_transform*point
     if not initialized:box=AABB(local,Vector3.ZERO);initialized=true
     else:box=box.expand(local)
   check(absf(box.get_center().x)<.015,"LOD"+str(level)+" pose"+str(pose)+" keeps symmetric panel travel")
   if pose==0:open_span=box.size.x
   if pose==2:closed_span=box.size.x
   for view: String in ["orbit","top","front"]:
    camera.position=Vector3(25,18,-30) if view=="orbit" else Vector3(0,40,0) if view=="top" else Vector3(0,2,-40)
    camera.look_at(Vector3(0,1,0),Vector3.FORWARD if view=="top" else Vector3.UP)
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var name_: String="sweep-lod%d-pose%d-%s.png"%[level,pose,view]
    check(root.get_texture().get_image().save_png(destination.path_join(name_))==OK,"render "+name_);images.append(name_)
  check(open_span>float(spec.geometry.span_m)*.97 and closed_span<open_span*.8,"LOD"+str(level)+" actual imported sweep reduces span")
  spans.append({"open_m":open_span,"closed_m":closed_span})
 var state: Dictionary={"v":Vector3(0,0,400),"gear":false,"flaps":false,"crashed":false,"afterburner":false}
 model.update_state(state);check(model.sweep_fraction==1.0,"first fast snapshot establishes imported rig closed baseline")
 state.gear=true;model.update_state(state);model._process(1.25)
 check(is_equal_approx(model.sweep_fraction,.5) and model.sweep_wings.all(func(p: Node3D):return absf(p.rotation.y)>deg_to_rad(float(spec.sweep.travel_degrees))*.49),"all six imported panels animate continuously from replicated gear flag")
 model._process(1.25);check(model.sweep_fraction==0.0 and model.sweep_wings.all(func(p: Node3D):return p.rotation.is_zero_approx()),"all imported pivots return to exact open endpoint")
 var result: Dictionary={"aircraft_id":aircraft_id,"event":"sweep_candidate_summary","status":"PASS" if valid else "FAIL","checks":checks,"lod_triangles":counts,"assembly_budgets":assembly_budgets,"spans":spans,"preview_files":images,"engine":Engine.get_version_info(),"scope":"actual rendered planned AI assembly; full recognition/flight/network/device/rights/15-gate acceptance pending"}
 var file: FileAccess=FileAccess.open(destination.path_join("sweep-candidate-validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close();print(JSON.stringify(result));quit(0 if valid else 1)
