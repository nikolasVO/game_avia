extends SceneTree
## Actual renderer/UI, synthetic state; never physical or public network acceptance.
var checks: Array[Dictionary]=[]
class CameraSession extends Node:
 var joined: bool=true
 var local_state: Dictionary=AviaFlight.spawn(3)
 var controls: Dictionary=AviaFlight.neutral()
 var visual_offset: Vector3=Vector3.ZERO
 var others: Dictionary={}
 var mode: String="free"
 func remote_state(id: int) -> Dictionary:return others[id]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().get_file().begins_with("game-avia-ui-check-"):
  push_error("Use tools/ui_preferences_check.py --camera with isolated rendered project");quit(2);return
 var parent: Node=Node.new();parent.name="Avia";root.add_child(parent)
 var session: CameraSession=CameraSession.new();parent.add_child(session)
 var world: Node3D=load("res://client/world.gd").new();parent.add_child(world)
 var remote: Dictionary=AviaFlight.spawn(0);remote.p=Vector3(60,100,0);session.others[22]=remote
 for index: int in AviaFlight.PLANES.size():
  # Recreate local visual exactly as a reconnect with another plane would.
  session.joined=false;world.update_session(session,.03);session.joined=true
  session.local_state=AviaFlight.spawn(index);session.local_state.p=Vector3(0,180,-200);session.local_state.pitch=.12;session.local_state.roll=.3
  for mode: int in 4:
   world.set_camera_mode(mode);world.update_session(session,.03)
   var mine: Node3D=world.planes[session.multiplayer.get_unique_id()]
   var internal: bool=mode in [1,3]
   check(mine.visible==not internal and world.planes[22].visible and world.cockpit_shell.visible==(mode==3) and is_equal_approx(world.camera.near,.08 if internal else .5),"local-only visibility and near plane %s/%d" % [AviaFlight.PLANES[index].aircraft_id,mode])
   check(world.camera.position.is_finite() and world.camera.basis.determinant()>.99,"finite orthonormal camera %d/%d" % [index,mode])
   if internal:check(world.camera.basis.is_equal_approx(Basis.from_euler(Vector3(.12,0,.3))),"internal view follows pitch and bank %d/%d" % [index,mode])
 var stable: Dictionary=session.local_state.duplicate(true)
 world.set_camera_mode(2);world.orbit=.9;world.look_pitch=.2;world.camera_zoom=1.6;world.update_session(session,1)
 var orbit_position: Vector3=world.camera.position
 world.orbit=-.9;world.update_session(session,1)
 check(world.camera.position.distance_to(orbit_position)>20 and session.local_state==stable,"orbit changes perspective without changing simulation")
 world.set_camera_mode(3);world.instrument_speed_unit=1;world.instrument_altitude_unit=1;world.language="ru";session.controls.throttle=.73;world.update_session(session,.2)
 check(world.cockpit and world.cockpit_shell.instruments.speed_unit==1 and world.cockpit_shell.instruments.altitude_unit==1 and world.cockpit_shell.instruments.language=="ru" and is_equal_approx(world.cockpit_shell.instruments.state.throttle,.73),"cockpit instruments receive units, locale and actual command throttle")
 check(world.cockpit_shell.meshes.size()==5 and world.cockpit_shell.display.size==Vector2i(640,160),"bounded five-mesh generic cabin and small instrument target")
 var fixture: Node=load("res://net/session.gd").new();fixture.name="Session";parent.add_child(fixture)
 var ui: CanvasLayer=load("res://client/ui.gd").new();ui.session=fixture;ui.world=world;parent.add_child(ui)
 ui.set_process(false)
 world.set_camera_mode(3)
 for i: int in 4:ui.labels.camera.pressed.emit()
 check(world.camera_mode==3 and ui.labels.camera.text.contains("Cockpit"),"actual camera button cycles all four views and updates caption")
 var cfg: ConfigFile=ConfigFile.new();cfg.load("user://settings.cfg")
 check(cfg.get_value("ui","camera_mode",-1)==3,"camera preference persists in isolated settings")
 ui.language="ru";ui._translate()
 check(ui.labels.camera.text=="Камера: Кабина","camera mode caption translates to Russian")
 world.set_camera_mode(2)
 var touch: Control=ui.touch;touch.show();touch.persistent_look=true
 await process_frame
 var press: InputEventScreenTouch=InputEventScreenTouch.new();press.index=7;press.position=Vector2(600,430);press.pressed=true;touch._input(press)
 var drag: InputEventScreenDrag=InputEventScreenDrag.new();drag.index=7;drag.relative=Vector2(80,35);touch._input(drag)
 press.pressed=false;touch._input(press)
 check(touch.look_yaw<-.4 and touch.look_pitch<-.1 and touch.look_id==-1 and touch.command().pitch==0 and touch.command().roll==0,"free look drag persists and never steers aircraft")
 touch.persistent_look=false;touch.release_look()
 check(touch.look_yaw==0 and touch.look_pitch==0,"chase/internal look returns after release")
 touch.persistent_look=true;touch.drag_look(Vector2(90000,-90000));touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(touch.look_yaw==0 and touch.look_pitch==0 and not touch.mouse_look and touch.throttle==0,"focus loss clears camera pointers and controls")
 var mouse: InputEventMouseButton=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT;mouse.pressed=true;touch._unhandled_input(mouse)
 var move: InputEventMouseMotion=InputEventMouseMotion.new();move.relative=Vector2(100,20);touch._unhandled_input(move)
 mouse.pressed=false;touch._unhandled_input(mouse)
 mouse.button_index=MOUSE_BUTTON_WHEEL_UP;mouse.pressed=true;touch._unhandled_input(mouse)
 check(touch.look_yaw<-.5 and touch.look_pitch<0 and touch.look_zoom<1 and not touch.mouse_look,"right mouse orbit and zoom use same bounded look controls")
 world.set_camera_mode(1)
 check(touch.look_yaw==0 and touch.look_pitch==0 and touch.look_zoom==1,"mode change clears retained orbit and zoom")
 fixture.joined=true;ui.menu.hide()
 var key: InputEventKey=InputEventKey.new();key.physical_keycode=KEY_C;key.pressed=true;ui._unhandled_key_input(key)
 check(world.camera_mode==2,"C keyboard shortcut cycles camera during flight")
 fixture.joined=false
 session.joined=false;world.update_session(session,.03)
 check(not world.cockpit_shell.visible and world.cockpit_shell.display.render_target_update_mode==SubViewport.UPDATE_DISABLED and not world.camera_ready and world.planes.is_empty(),"disconnect stops cockpit texture updates and clears visuals")
 var directory: String=OS.get_environment("AVIA_UI_CAPTURE_DIR")
 ui.hide();session.joined=true;session.controls.throttle=.73
 var views: int=0
 for index: int in [0,3,6]:
  session.joined=false;world.update_session(session,.03);session.joined=true
  session.local_state=AviaFlight.spawn(index);session.local_state.p=Vector3(0,90,250);session.local_state.v=Vector3(0,0,-100)
  for mode: int in 4:
   world.set_camera_mode(mode)
   if mode==2:world.orbit=.8;world.look_pitch=.1
   world.update_session(session,.2)
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(directory.path_join("camera-%d-%d.png" % [index,mode]))==OK,"render capture %d/%d" % [index,mode]);views+=1
 world.cockpit_shell.display.get_texture().get_image().save_png(directory.path_join("cockpit-panel.png"))
 var network: Dictionary={"tested":false}
 if OS.get_environment("AVIA_UI_NETWORK_CHECK")=="1":
  ui.show();ui.menu.hide();ui.touch.show();ui.language="en";ui._translate()
  var connect_error: Error=fixture.connect_to("127.0.0.1",24678,{"plane":3,"mode":"free"})
  var deadline: int=Time.get_ticks_msec()+8000
  while not fixture.joined and Time.get_ticks_msec()<deadline:await process_frame
  check(connect_error==OK and fixture.joined,"camera test real ENet/DTLS admission")
  var started: int=fixture.snapshots
  if fixture.joined:
   fixture.controls.throttle=.8;fixture.controls.pitch=.15
   for mode: int in 4:
    world.set_camera_mode(mode)
    var stop: int=Time.get_ticks_msec()+2200
    while Time.get_ticks_msec()<stop and fixture.joined:
     world.update_session(fixture,.03);ui._process(.03);await process_frame
    check(fixture.joined and fixture.snapshots>started+15 and fixture.others.size()==1 and world.planes.size()==2,"camera %d receives authoritative local/remote snapshots" % mode)
    var mine: Node3D=world.planes.get(fixture.multiplayer.get_unique_id())
    check(is_instance_valid(mine) and mine.visible==(mode in [0,2]),"camera %d hides only own network visual" % mode)
    check(ui.labels.camera.get_global_rect().end.x<ui.root.size.x-20 and ui.top_buttons[-1].get_global_rect().end.x<=ui.root.size.x,"camera %d actions remain inside viewport" % mode)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory.path_join("camera-network-%d.png" % mode))
    started=fixture.snapshots
   network={"tested":true,"snapshots":fixture.snapshots,"commands":fixture.commands_sent,"seen_peers":fixture.seen_peers,"joined":fixture.joined}
   ui.show_menu();world.update_session(fixture,.03)
   check(not fixture.joined and not world.cockpit_shell.visible and world.planes.is_empty(),"real network menu disconnect clears cabin and planes")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"camera_summary","status":"PASS" if ok else "FAIL","checks":checks,"rendered_views":views,"network":network,"scope":"actual desktop Godot render/UI with synthetic states and optional actual two-client ENet/DTLS; no phone/human/public-network acceptance"}))
 parent.queue_free();await process_frame;quit(0 if ok else 1)
