extends "res://main.gd"
## Real local and remote state drives visible panels, no protocol extension.
var observed: Dictionary={}
func _physics_process(delta: float) -> void:
 super._physics_process(delta)
 if session.joined:
  session.controls.brake=fmod(elapsed,8.0)>3.0 and fmod(elapsed,8.0)<5.0
func _process(delta: float) -> void:
 super._process(delta)
 if not world or not session.joined:return
 for id: int in world.planes:
  var model: AviaAircraft=world.planes[id]
  if not model.airbrake_instances:continue
  if not observed.has(id):observed[id]={"local":id==session.multiplayer.get_unique_id(),"targets":{},"intermediate_frames":0,"open_endpoint":false,"closed_endpoint":false,"transform_errors":0}
  var row: Dictionary=observed[id];row.targets[str(model.airbrake_target)]=true
  if model.airbrake_deployment>.01 and model.airbrake_deployment<.99:row.intermediate_frames+=1
  if model.airbrake_deployment==0:row.closed_endpoint=true
  if model.airbrake_deployment==1:row.open_endpoint=true
  for i: int in model.airbrake_hinges.size():
   var expected: Transform3D=model.airbrake_hinges[i];expected.basis=expected.basis*Basis(Vector3.RIGHT,model.airbrake_angles[i]*model.airbrake_deployment)
   if not expected.is_equal_approx(model.airbrake_instances.multimesh.get_instance_transform(i)):row.transform_errors+=1
func _exit_tree() -> void:
 var ok: bool=observed.size()>=2
 for row: Dictionary in observed.values():ok=ok and row.targets.size()==2 and row.intermediate_frames>0 and row.open_endpoint and row.closed_endpoint and row.transform_errors==0
 print(JSON.stringify({"event":"airbrake_network_summary","status":"PASS" if ok else "FAIL","observed":observed.values(),"scope":"actual rendered local/remote ENet/DTLS state, no public/device acceptance"}))
