extends SceneTree
## Own planned conditioning geometry, independent of production/network admission.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="mig31":spec=row
 var before: String=JSON.stringify(AviaCatalog.all())
 check(not spec.is_empty() and not spec.playable and AviaCatalog.index_of("mig31")==-1 and AviaFlight.PLANES.size()==9,"planned interceptor never enters nine playable prototypes")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec,false);root.add_child(model);model.set_process(false)
 check(model.get_node_or_null("AIModel")==null,"conditioning uses only own authored geometry")
 var g: Dictionary=spec.geometry
 check(g.box_body_sections_m.size()==7 and g.box_body_sections_m[0][0]==-11.35,"explicit pointed nose and rectangular rear metre sections")
 check(g.engines==2 and g.intake_layout=="side_pair" and g.intake_size_m[1]>1.3,"two engines with large rectangular paired intakes")
 check(g.canopy_sections_m.size()==5 and float(g.canopy_sections_m[3][0])-float(g.canopy_sections_m[1][0])>3.4,"separate elongated tandem-style canopy")
 check(g.fin_outline_m.size()==4 and g.fin_cant_degrees==8 and g.wing_dihedral_degrees<0,"angular paired outward fins and slight negative wing dihedral")
 var counts: Array[int]=[];var bounds: AABB;var good: bool=true;var symmetric: bool=true
 for name_: String in ["Airframe","LOD1","Distant"]:
  var node: MeshInstance3D=model.get_node(name_);var vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL];counts.append(vertices.size()/3)
  var keys: Dictionary={}
  for point: Vector3 in vertices:keys[Vector3i(roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000))]=true
  for point: Vector3 in vertices:
   good=good and point.is_finite();symmetric=symmetric and keys.has(Vector3i(roundi(-point.x*10000),roundi(point.y*10000),roundi(point.z*10000)))
  for normal: Vector3 in normals:good=good and normal.is_finite() and normal.length()>.99
  for i: int in range(0,vertices.size(),3):good=good and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()>1e-9
  if name_=="Airframe":bounds=node.mesh.get_aabb()
 check(good,"all authored LOD triangles finite, nondegenerate with unit normals")
 check(symmetric,"all body LOD vertices have exact mirrored partners")
 check(counts[0]<2000 and counts[1]<counts[0] and counts[2]<counts[1],"explicit decreasing lightweight conditioning tiers")
 check(absf(bounds.size.x-13.5)<.01 and absf(bounds.size.z-22.7)<.01,"built bounds match labelled provisional span and length")
 check(model.exhaust.get_child_count()==2 and model.sweep_wings.is_empty() and model.vectoring_nozzles.is_empty(),"twin exhaust without invented swing wing or thrust vectoring")
 check(model.gear_instances.multimesh.instance_count==3,"existing deployable gear retained for later fidelity review")
 check(JSON.stringify(AviaCatalog.all())==before,"construction leaves authoritative catalog unchanged")
 var passed: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"interceptor_reference_summary","status":"PASS" if passed else "FAIL","checks":checks,"triangles":counts,"bounds":str(bounds),"scope":"own provisional conditioning geometry only; primary dimensions/recognition and full15gates open","production_accepted":false,"playable":false}));quit(0 if passed else 1)
