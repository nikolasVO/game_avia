extends SceneTree
## Planned geometry QA only; does not expose a new aircraft in network admission.
var checks: Array[Dictionary]=[]
var valid: bool=true
func check(ok: bool,label: String) -> void:
 checks.append({"check":label,"ok":ok});valid=valid and ok
func bounds(model: Node3D) -> AABB:
 var points: Array[Vector3]=[]
 for node: Node in model.find_children("PanelLOD0","MeshInstance3D",true,false):
  for point: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:points.append(model.global_transform.affine_inverse()*node.global_transform*point)
 var box: AABB=AABB(points[0],Vector3.ZERO)
 for point: Vector3 in points:box=box.expand(point)
 return box
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var spec: Dictionary={}
 for row: Dictionary in AviaCatalog.all():
  if row.aircraft_id=="f14":spec=row
 check(not spec.is_empty() and not spec.playable and AviaCatalog.index_of("f14")==-1 and AviaCatalog.playable().size()==9,"F14 remains planned and unavailable; nine playable prototypes preserved")
 var model: AviaAircraft=AviaFighterVisual.create_spec(spec);root.add_child(model)
 check(model.sweep_wings.size()==2 and model.sweep_wings[0].get_child_count()==3 and model.sweep_wings[1].get_child_count()==3,"two independently pivoted wings with three matching LOD ranges")
 var open: AABB=bounds(model);model.pose_sweep(1);var closed: AABB=bounds(model)
 check(open.size.x>19.0 and closed.size.x<open.size.x*.8 and closed.end.z>open.end.z+2,"sweep reduces span and moves both wing tips aft")
 check(absf(closed.get_center().x)<.001 and absf(open.get_center().x)<.001,"left and right panels retain mirror symmetry through travel")
 var finite: bool=true;var triangles: int=0
 for node: Node in model.find_children("PanelLOD*","MeshInstance3D",true,false):
  var vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];triangles+=vertices.size()/3
  for i: int in range(0,vertices.size(),3):finite=finite and vertices[i].is_finite() and (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()>1e-9
 check(finite and triangles==72,"all six panel meshes finite and nondegenerate; 24 triangles at each distance tier")
 var state: Dictionary={"v":Vector3(0,0,400),"gear":false,"flaps":false,"crashed":false,"afterburner":false}
 model.update_state(state);check(model.sweep_fraction==1.0,"initial state establishes sweep baseline")
 state.gear=true;model.update_state(state);check(model.sweep_target==0.0 and model.sweep_fraction==1.0,"gear requests open wings without an instantaneous snap")
 model._process(1.25);check(is_equal_approx(model.sweep_fraction,.5),"sweep travels at bounded frame-independent rate")
 state.gear=false;model.update_state(state);model._process(.625);check(is_equal_approx(model.sweep_fraction,.75),"mid-travel reversal continues smoothly")
 state.flaps=true;model.update_state(state);model._process(2.5);check(model.sweep_fraction==0.0,"flaps interlock returns wings fully open")
 state.flaps=false;state.v=Vector3.ZERO;model.update_state(state);check(model.sweep_target==0.0,"low-speed state selects fully open wings")
 model.pose_sweep(-10);check(model.sweep_fraction==0.0,"negative preview fraction clamps safely");model.pose_sweep(10);check(model.sweep_fraction==1.0,"excess preview fraction clamps safely")
 print(JSON.stringify({"event":"sweep_reference_summary","status":"PASS" if valid else "FAIL","checks":checks,"open_span_m":open.size.x,"closed_span_m":closed.size.x,"scope":"authored planned F14-style geometry/animation only; primary variant facts, AI body, sweep aerodynamics, multiplayer and production acceptance remain pending"}));quit(0 if valid else 1)
