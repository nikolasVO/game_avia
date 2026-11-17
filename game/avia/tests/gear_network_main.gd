extends "res://main.gd"
## Observe the real client world receiving predicted and remote authoritative flags.
var observed: Dictionary={}
func _process(delta: float) -> void:
 super._process(delta)
 if not world or not session.joined:return
 for id: int in world.planes:
  var model: AviaAircraft=world.planes[id]
  if not model.gear_instances:continue
  if not observed.has(id):observed[id]={"local":id==session.multiplayer.get_unique_id(),"targets":{},"intermediate_frames":0,"up_endpoint":false,"down_endpoint":false,"transform_errors":0}
  var row: Dictionary=observed[id];row.targets[str(model.gear_target)]=true
  if model.gear_deployment>.01 and model.gear_deployment<.99:row.intermediate_frames+=1
  if model.gear_deployment==0 and not model.landing_gear.visible:row.up_endpoint=true
  if model.gear_deployment==1 and model.landing_gear.visible:row.down_endpoint=true
  for i: int in model.gear_legs.size():
   if not model.gear_instances.multimesh.get_instance_transform(i).is_equal_approx(model.gear_legs[i].transform):row.transform_errors+=1
func _exit_tree() -> void:
 var ok: bool=observed.size()>=2
 for row: Dictionary in observed.values():ok=ok and row.targets.size()==2 and row.intermediate_frames>0 and row.up_endpoint and row.down_endpoint and row.transform_errors==0
 print(JSON.stringify({"event":"gear_network_summary","status":"PASS" if ok else "FAIL","observed":observed.values(),"scope":"rendered local/remote real network flags; not public/device acceptance"}))
