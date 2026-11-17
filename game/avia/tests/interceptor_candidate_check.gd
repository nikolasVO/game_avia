extends SceneTree
## Actual rendered planned assembly; never admits a plane to public rooms.
var checks: Array[Dictionary]=[]
var directory: String="/tmp/avia-interceptor-candidate"
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func triangles(mesh: Mesh) -> int:
 var total: int=0
 for surface: int in mesh.get_surface_count():
  var a: Array=mesh.surface_get_arrays(surface);var ix: Variant=a[Mesh.ARRAY_INDEX]
  total+=(ix.size() if ix!=null and not ix.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
 return total
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
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Interceptor check requires actual renderer");quit(2);return
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):directory=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(directory)
 root.size=Vector2i(800,800);root.content_scale_size=Vector2i(800,800)
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="mig31":spec=row
 check(not spec.playable and AviaCatalog.index_of("mig31")==-1 and AviaFlight.PLANES.size()==9,"planned interceptor stays outside nine admitted prototypes")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec,true);root.add_child(model);model.set_process(false)
 check(model.has_node("AIModel") and model.airframe_source.contains("AI candidate"),"actual imported body selected without procedural fallback")
 var nozzles: Array[Node]=model.find_children("RepairedNozzle*","Node3D",true,false)
 check(nozzles.size()==2 and nozzles[0].position.x==-nozzles[1].position.x,"two authored mirrored nozzles repair unclear generated engine exits")
 for nozzle: Node3D in nozzles:
  var limits: Vector2=body_limits(model,nozzle.position)
  check(limits.x<nozzle.position.y-.46 and limits.y>nozzle.position.y+.46,"nozzle inlet intersects measured imported body, not floating below it")
 var tiers: Array=[[],[],[]];var counts: Array[int]=[0,0,0];var boxes: Array[AABB]=[AABB(),AABB(),AABB()]
 for node: Node in model.get_node("AIModel").find_children("*","MeshInstance3D",true,false):
  if str(node.name).begins_with("COLLISION"):
   check(not node.visible,"authoring collider stays hidden");continue
  var level: int=-1
  for i: int in 3:
   if str(node.name).begins_with("LOD"+str(i)):level=i
  check(level>=0,"body has explicit LOD identity")
  if level<0:continue
  tiers[level].append(node);counts[level]+=triangles(node.mesh)
  var transform_: Transform3D=model.global_transform.affine_inverse()*node.global_transform
  var box: AABB=transform_*node.mesh.get_aabb()
  boxes[level]=box if tiers[level].size()==1 else boxes[level].merge(box)
  var finite: bool=true;var nondegenerate: bool=true
  for surface: int in node.mesh.get_surface_count():
   var a: Array=node.mesh.surface_get_arrays(surface);var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ix: Variant=a[Mesh.ARRAY_INDEX]
   for point: Vector3 in points:finite=finite and point.is_finite()
   for normal: Vector3 in a[Mesh.ARRAY_NORMAL]:finite=finite and normal.is_finite()
   var count: int=ix.size() if ix!=null and not ix.is_empty() else points.size()
   for j: int in range(0,count,3):
    var pa: Vector3=points[ix[j] if ix!=null and not ix.is_empty() else j];var pb: Vector3=points[ix[j+1] if ix!=null and not ix.is_empty() else j+1];var pc: Vector3=points[ix[j+2] if ix!=null and not ix.is_empty() else j+2]
    nondegenerate=nondegenerate and (pb-pa).cross(pc-pa).length()*.5>1e-12
  check(finite and nondegenerate,"LOD"+str(level)+" actual vertices/normals/triangles finite and nondegenerate")
  check(node.visibility_range_begin==[0,350,900][level] and node.visibility_range_end==[350,900,2500][level],"LOD"+str(level)+" explicit visibility interval preserved")
 for level: int in 3:
  check(tiers[level].size()==1 and counts[level]>0 and counts[level]<=[20000,7000,2000][level],"LOD"+str(level)+" one body within triangle budget")
  check(boxes[level].size.distance_to(Vector3(13.5,4.9,22.7))<.15 and absf(boxes[level].get_center().x)<.015,"LOD"+str(level)+" bounds and mirrored centre preserved")
 var budgets: Array[Dictionary]=[]
 for distance: int in [100,400,600,950]:
  var count: int=0
  for node: Node in model.find_children("*","GeometryInstance3D",true,false):
   if str(node.name).begins_with("COLLISION"):continue
   if distance<node.visibility_range_begin or (node.visibility_range_end>0 and distance>=node.visibility_range_end):continue
   if node is MeshInstance3D:count+=triangles(node.mesh)
   elif node is MultiMeshInstance3D:count+=triangles(node.multimesh.mesh)*node.multimesh.instance_count
  var limit: int=20000 if distance<350 else 7000 if distance<900 else 2000
  check(count>0 and count<=limit,"body/gear/both afterburners fit budget at "+str(distance)+"m")
  budgets.append({"distance_m":distance,"triangles":count,"limit":limit})
 var state: Dictionary={"v":Vector3(0,0,100),"gear":true,"flaps":false,"afterburner":false,"crashed":false}
 var original: Dictionary=state.duplicate(true);model.update_state(state)
 check(state==original and model.gear_deployment==1 and not model.exhaust.visible,"snapshot establishes deployed gear without changing simulation")
 state.gear=false;state.afterburner=true;model.update_state(state);model.advance_gear(model.gear_duration*.5)
 check(is_equal_approx(model.gear_deployment,.5) and model.exhaust.visible,"replicated flags drive intermediate gear and afterburners")
 model.advance_gear(model.gear_duration)
 check(model.gear_deployment==0 and not model.landing_gear.visible,"gear reaches exact hidden endpoint")
 state.crashed=true;model.update_state(state)
 check(not model.exhaust.visible,"crash suppresses afterburners")
 var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243744");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;root.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);root.add_child(sun)
 var camera: Camera3D=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=28;camera.current=true
 var previews: Array[String]=[]
 for level: int in 3:
  for other: int in 3:
   for node: MeshInstance3D in tiers[other]:node.visible=other==level;node.visibility_range_begin=0;node.visibility_range_end=0
  for view: String in ["orbit","top","front","side","rear"]:
   camera.position=Vector3(24,18,-28) if view=="orbit" else Vector3(0,40,0) if view=="top" else Vector3(0,2,-40) if view=="front" else Vector3(0,2,40) if view=="rear" else Vector3(40,2,0)
   camera.look_at(Vector3(0,1.5,0),Vector3.FORWARD if view=="top" else Vector3.UP)
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   var name_: String="interceptor-lod%d-%s.png"%[level,view]
   check(root.get_texture().get_image().save_png(directory.path_join(name_))==OK,"render "+name_);previews.append(name_)
 var result: Dictionary={"status":"PASS" if checks.all(func(c: Dictionary):return c.ok) else "FAIL","checks":checks,"body_triangles":counts,"assembly_budgets":budgets,"preview_files":previews,"engine":Engine.get_version_info(),"scope":"actual planned-only interceptor assembly geometry/render/system animation; recognition/human/network/phone/rights and15-gate acceptance pending","production_accepted":false,"playable":false}
 var file: FileAccess=FileAccess.open(directory.path_join("interceptor-candidate-validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close();print(JSON.stringify(result));quit(0 if result.status=="PASS" else 1)
