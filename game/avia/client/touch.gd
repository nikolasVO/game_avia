extends Control
## Pointer IDs are captured independently; releases outside widgets and focus loss clear state.
var stick_id: int=-1
var throttle_id: int=-1
var action_id: int=-1
var stick: Vector2=Vector2.ZERO
var throttle: float=0.0
var fire: bool=false
var respawn: bool=false
var brake: bool=false
var left_handed: bool=false
var invert: bool=false
var sensitivity: float=1.0
var assistance: bool=true
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func centers() -> Array:
 var scale: float=minf(size.x/1280.0,size.y/720.0)
 var left: Vector2=Vector2(145*scale,size.y-145*scale)
 var right: Vector2=Vector2(size.x-140*scale,size.y-145*scale)
 return [right,left] if left_handed else [left,right]
func clear_pointers() -> void:
 stick_id=-1;throttle_id=-1;action_id=-1;stick=Vector2.ZERO;fire=false;respawn=false;brake=false
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:clear_pointers();throttle=0
func _input(event: InputEvent) -> void:
 if not visible:return
 var center: Array=centers()
 var radius: float=90.0*minf(size.x/1280.0,size.y/720.0)
 if event is InputEventScreenTouch:
  var touch: InputEventScreenTouch=event
  if not touch.pressed:
   if touch.index==stick_id:stick_id=-1;stick=Vector2.ZERO
   if touch.index==throttle_id:throttle_id=-1
   if touch.index==action_id:action_id=-1;fire=false
  elif touch.position.distance_to(center[0])<radius*1.5 and stick_id==-1:stick_id=touch.index;stick=(touch.position-center[0])/radius
  elif touch.position.distance_to(center[1])<radius*1.5 and throttle_id==-1:throttle_id=touch.index;throttle=clampf(0.5-(touch.position.y-center[1].y)/(radius*2),0,1)
  elif touch.position.distance_to(Vector2(center[1].x,size.y-330*size.y/720))<radius*0.7 and action_id==-1:action_id=touch.index;fire=true
 elif event is InputEventScreenDrag:
  var drag: InputEventScreenDrag=event
  if drag.index==stick_id:stick=((drag.position-center[0])/radius).limit_length()
  if drag.index==throttle_id:throttle=clampf(0.5-(drag.position.y-center[1].y)/(radius*2),0,1)
 queue_redraw()
func command() -> Dictionary:
 var c: Dictionary=AviaFlight.neutral()
 var pitch: float=-stick.y
 var roll: float=stick.x
 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):pitch+=1
 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):pitch-=1
 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):roll-=1
 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):roll+=1
 if Input.is_physical_key_pressed(KEY_SHIFT):throttle=minf(1,throttle+AviaFlight.DT*0.45)
 if Input.is_physical_key_pressed(KEY_CTRL):throttle=maxf(0,throttle-AviaFlight.DT*0.45)
 c.pitch=clampf(pitch*sensitivity*(-1 if invert else 1),-1,1)
 c.roll=clampf(roll*sensitivity,-1,1)
 c.yaw=float(Input.is_physical_key_pressed(KEY_Q))-float(Input.is_physical_key_pressed(KEY_E))
 c.throttle=throttle;c.brake=brake or Input.is_physical_key_pressed(KEY_SPACE)
 c.fire=fire or Input.is_physical_key_pressed(KEY_F)
 c.respawn=respawn or Input.is_physical_key_pressed(KEY_R)
 respawn=false
 return c
func _draw() -> void:
 var center: Array=centers();var r: float=90*minf(size.x/1280.0,size.y/720.0)
 draw_circle(center[0],r,Color(0.1,0.2,0.24,0.38));draw_arc(center[0],r,0,TAU,48,Color(0.8,0.9,0.86,0.6),2)
 draw_circle(center[0]+stick*r,r*0.32,Color(0.94,0.82,0.56,0.8))
 draw_style_box(_throttle_style(),Rect2(center[1]-Vector2(r*0.4,r),Vector2(r*0.8,r*2)))
 draw_rect(Rect2(center[1]+Vector2(-r*0.32,r-throttle*r*2),Vector2(r*0.64,throttle*r*2)),Color("e2bd75"))
 draw_circle(Vector2(center[1].x,size.y-330*size.y/720),r*0.55,Color(0.65,0.35,0.25,0.65))
func _throttle_style() -> StyleBoxFlat:
 var s: StyleBoxFlat=StyleBoxFlat.new();s.bg_color=Color(0.1,0.2,0.24,0.5);s.corner_radius_top_left=16;s.corner_radius_top_right=16;s.corner_radius_bottom_left=16;s.corner_radius_bottom_right=16;return s
