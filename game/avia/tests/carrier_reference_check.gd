extends SceneTree
## Planned conditioning geometry QA; no network admission or aircraft acceptance.
var checks: Array[Dictionary]=[]
var valid: bool=true
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"ok":ok});valid=valid and ok
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="fa18e":spec=row
 check(not spec.is_empty() and not spec.playable and AviaCatalog.index_of("fa18e")==-1 and AviaCatalog.playable().size()==9,"FA18E stays planned; nine existing playable prototypes preserved")
 var before: String=JSON.stringify(spec)
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec);root.add_child(model)
 check(JSON.stringify(spec)==before and model.get_node_or_null("AIModel")==null,"conditioning uses authored geometry and leaves catalog untouched")
 var g: Dictionary=spec.geometry
 check(g.wing_outline_m.size()==4 and g.lerx_outline_m.size()==4 and g.stabilizer_outline_m.size()==4,"explicit clipped wing, broad LERX and separate tail half-planforms")
 check(g.fin_cant_degrees==22 and g.engines==2 and g.intake_layout=="side_pair","paired canted fins, close engines and paired intakes configured")
 var counts: Array[int]=[];var finite: bool=true;var symmetric: bool=true;var bounds: AABB
 for name_: String in ["Airframe","LOD1","Distant"]:
  var mesh: MeshInstance3D=model.get_node(name_);var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];counts.append(vertices.size()/3)
  var keys: Dictionary={}
  for v: Vector3 in vertices:keys[Vector3i(roundi(v.x*10000),roundi(v.y*10000),roundi(v.z*10000))]=true
  for v: Vector3 in vertices:
   finite=finite and v.is_finite();symmetric=symmetric and keys.has(Vector3i(roundi(-v.x*10000),roundi(v.y*10000),roundi(v.z*10000)))
  for i: int in range(0,vertices.size(),3):finite=finite and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()>1e-9
  if name_=="Airframe":bounds=mesh.mesh.get_aabb()
 check(finite,"all three authored LODs have finite nondegenerate triangles")
 check(symmetric,"all authored body vertices retain exact left/right mirror symmetry")
 check(counts[0]<2000 and counts[1]<counts[0] and counts[2]<counts[1],"authored tiers reduce geometry without a high triangle conditioning mesh")
 check(bounds.size.x>=13.6 and bounds.size.x<13.9 and bounds.size.z>17 and bounds.size.z<20,"model fits its labelled provisional game dimensions")
 check(model.sweep_wings.is_empty() and model.vectoring_nozzles.is_empty() and model.exhaust.get_child_count()==2,"no invented swing wing or thrust vectoring; two exhaust cues")
 check(model.gear_instances.multimesh.instance_count==3,"existing deployable gear assembly preserved")
 # Differentiation is measured from built geometry, rather than only config labels.
 var other: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="f15c":other=row
 var eagle: AviaAircraft=AviaFighterVisual.create_spec(other);root.add_child(eagle)
 check(eagle.get_node("Airframe").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()!=model.get_node("Airframe").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(),"carrier reference has distinct authored topology from F15C")
 print(JSON.stringify({"event":"carrier_reference_summary","status":"PASS" if valid else "FAIL","checks":checks,"triangles":counts,"bounds":str(bounds),"scope":"own provisional conditioning geometry only; recognition, variant facts, inference and 15 production gates remain open"}))
 quit(0 if valid else 1)
