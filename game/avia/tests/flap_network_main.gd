extends "res://main.gd"
## Real local/remote approved state drives one configured visual pair.
var observed: Dictionary={}
func _physics_process(delta: float) -> void:
 super._physics_process(delta)
 if session.joined:session.controls.flaps=fmod(elapsed,8.0)>3.0 and fmod(elapsed,8.0)<5.0
func _process(delta: float) -> void:
 super._process(delta)
 if not world or not session.joined:return
 for id: int in world.planes:
  var model: AviaAircraft=world.planes[id]
  if not model.flap_instances:continue
  if not observed.has(id):observed[id]={"local":id==session.multiplayer.get_unique_id(),"targets":{},"intermediate_frames":0,"deployed":false,"neutral":false,"errors":0}
  var row: Dictionary=observed[id];row.targets[str(model.flap_target)]=true
  if model.flap_deployment>.01 and model.flap_deployment<.99:row.intermediate_frames+=1
  if model.flap_deployment==0:row.neutral=true
  if model.flap_deployment==1:row.deployed=true
  for i: int in model.flap_hinges.size():
   var expected: Transform3D=model.flap_hinges[i];expected.basis=Basis(model.flap_axes[i],model.flap_angles[i]*model.flap_deployment)*expected.basis
   if not expected.is_equal_approx(model.flap_instances.multimesh.get_instance_transform(i)):row.errors+=1
func _exit_tree() -> void:
 var ok: bool=observed.size()>=2
 for row: Dictionary in observed.values():ok=ok and row.targets.size()==2 and row.intermediate_frames>0 and row.deployed and row.neutral and row.errors==0
 print(JSON.stringify({"event":"flap_network_summary","status":"PASS" if ok else "FAIL","observed":observed.values(),"scope":"actual rendered local/remote ENet/DTLS state, no external/device acceptance"}))
