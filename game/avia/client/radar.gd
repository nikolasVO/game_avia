extends Control
var session: Node
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
 if not session or not session.joined or session.local_state.is_empty():return
 var center: Vector2=Vector2(85,85)
 draw_circle(center,78,Color(0.08,0.18,0.22,0.6));draw_arc(center,78,0,TAU,48,Color(0.7,0.85,0.8,0.6),1)
 draw_line(center-Vector2(72,0),center+Vector2(72,0),Color(1,1,1,0.16));draw_line(center-Vector2(0,72),center+Vector2(0,72),Color(1,1,1,0.16))
 var own: Dictionary=session.local_state
 draw_colored_polygon(PackedVector2Array([center+Vector2(0,-6),center+Vector2(-4,5),center+Vector2(4,5)]),Color("edc682"))
 for id: int in session.others:
  var p: Vector3=session.remote_state(id).p-own.p
  var relative: Vector3=Basis(Vector3.UP,-float(own.yaw))*p
  draw_circle(center+Vector2(relative.x,relative.z).limit_length(1500)/1500.0*72,3,Color("7bddd0"))
 if session.mode=="race":
  var next: int=int(session.local_race.get("next",0))
  if next<AviaRules.CHECKPOINTS.size():
   var relative: Vector3=Basis(Vector3.UP,-float(own.yaw))*(AviaRules.CHECKPOINTS[next]-own.p)
   draw_circle(center+Vector2(relative.x,relative.z).limit_length(1500)/1500.0*72,5,Color("e7c46f"))
