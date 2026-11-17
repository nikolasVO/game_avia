extends SceneTree
## Own planned historical delta reference; no admission or production acceptance.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="mig21":spec=row
 var before: String=JSON.stringify(AviaCatalog.all())
 check(not spec.playable and AviaCatalog.index_of("mig21")==-1 and AviaFlight.PLANES.size()==9,"planned reference preserves nine flight selections")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec,false);root.add_child(model);model.set_process(false)
 var g: Dictionary=spec.geometry
 check(model.get_node_or_null("AIModel")==null,"reference uses only own geometry")
 check(g.engines==1 and g.fin_count==1 and model.exhaust.get_child_count()==1,"single engine, fin and exhaust")
 check(g.intake_layout=="nose_ring" and g.nose_intake.inner_radius_m<g.nose_intake.outer_radius_m and g.nose_intake.cone_sections_m[0][0]<g.nose_intake.lip_z_m,"annular nose inlet with protruding separate cone, no chin/side intake")
 check(g.wing_outline_m.size()==4 and g.stabilizer_outline_m.size()==4 and g.stabilizer_outline_m[0][1]>g.wing_outline_m[3][1],"delta main wing and separate aft tailplane")
 var counts: Array[int]=[];var good: bool=true;var symmetric: bool=true;var bounds: AABB
 for name_: String in ["Airframe","LOD1","Distant"]:
  var node: MeshInstance3D=model.get_node(name_);var vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL];counts.append(vertices.size()/3)
  var keys: Dictionary={}
  for point: Vector3 in vertices:keys[Vector3i(roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000))]=true
  for point: Vector3 in vertices:good=good and point.is_finite();symmetric=symmetric and keys.has(Vector3i(roundi(-point.x*10000),roundi(point.y*10000),roundi(point.z*10000)))
  for normal: Vector3 in normals:good=good and normal.is_finite() and normal.length()>.99
  for i: int in range(0,vertices.size(),3):good=good and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()>1e-9
  if name_=="Airframe":bounds=node.mesh.get_aabb()
 check(good,"three authored LODs have finite nondegenerate triangles and unit normals")
 check(symmetric,"three authored LODs are exactly mirrored")
 check(counts[0]<2000 and counts[1]<counts[0] and counts[2]<counts[1],"explicit decreasing geometry tiers")
 check(absf(bounds.size.x-7.15)<.01 and absf(bounds.size.z-14.7)<.01,"rendered bounds match provisional dimensions")
 check(model.sweep_wings.is_empty() and model.vectoring_nozzles.is_empty() and model.gear_instances.multimesh.instance_count==3,"no invented sweep/vectoring; existing gear available")
 check(JSON.stringify(AviaCatalog.all())==before,"reference construction leaves catalog immutable")
 var passed: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"delta_reference_summary","status":"PASS" if passed else "FAIL","checks":checks,"triangles":counts,"bounds":str(bounds),"playable":false,"production_accepted":false,"scope":"own conditioning geometry only; primary variant/recognition/rights and all aircraft gates remain open"}));quit(0 if passed else 1)
