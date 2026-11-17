extends SceneTree
## Real UI restoration/option application in an isolated user directory.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 if not OS.get_user_data_dir().get_file().begins_with("game-avia-ui-check-"):
  push_error("Use tools/ui_preferences_check.py: isolated test user directory required");quit(2);return
 var cfg: ConfigFile=ConfigFile.new()
 cfg.set_value("flight","aircraft_id","su27");cfg.set_value("flight","profile",2);cfg.set_value("flight","mode","pvp");cfg.set_value("net","port",24677);cfg.save("user://settings.cfg")
 var parent: Node=Node.new();parent.name="Avia";root.add_child(parent)
 var session: Node=load("res://net/session.gd").new();session.name="Session";parent.add_child(session)
 var world: Node3D=load("res://client/world.gd").new();parent.add_child(world)
 var ui: CanvasLayer=load("res://client/ui.gd").new();ui.session=session;ui.world=world;parent.add_child(ui)
 check(ui.select_plane.selected==4 and ui.select_profile.selected==0 and ui.preferred_profile==2 and ui.select_profile.disabled and ui.select_mode.selected==2 and int(ui.port.value)==24677,"actual UI restores stable Su27 ID/UDP port and locks competitive profile while retaining preference")
 ui.apply_connection_options({"plane":3,"profile":1,"mode":"race","connect":"127.0.0.1","port":24678})
 check(ui.select_plane.selected==3 and ui.select_profile.selected==0 and ui.preferred_profile==1 and ui.select_mode.selected==1 and int(ui.port.value)==24678,"direct admission options agree with retry menu")
 ui.select_mode.select(0);ui._mode_changed(0)
 check(ui.select_profile.selected==1 and not ui.select_profile.disabled,"free flight restores preferred Realistic profile after competitive Arcade")
 ui.select_mode.select(1);ui._mode_changed(1)
 ui.show_menu();await process_frame;await process_frame
 check(ui.select_plane.selected==3 and not ui.hud.visible and not ui.radar.visible and ui.top_buttons.all(func(b: Button):return not b.visible),"menu retains selection and hides flight-only HUD/buttons/radar")
 # Calling the actual join path saves preferences before asynchronous model preparation.
 ui.join()
 var saved: ConfigFile=ConfigFile.new();saved.load("user://settings.cfg")
 check(saved.get_value("flight","aircraft_id","")=="f16c" and saved.get_value("flight","profile",-1)==1 and saved.get_value("flight","mode","")=="race" and saved.get_value("net","port",0)==24678,"actual join persists aircraft ID rather than mutable catalog index")
 # Cancel the pending preparation; it must not create a late transport.
 ui.show_menu();await process_frame;await process_frame
 check(not session.joined and session.peer==null and not ui.preparing and ui.menu.visible,"cancelled preparation keeps a usable retry menu")
 if OS.get_environment("AVIA_UI_NETWORK_CHECK")=="1":
  ui.join()
  var deadline: int=Time.get_ticks_msec()+10000
  while not session.joined and Time.get_ticks_msec()<deadline:await process_frame
  check(session.joined and session.local_state.get("plane",-1)==3 and session.local_state.get("profile",-1)==0 and session.mode=="race","actual UI connects via configured nondefault UDP port and receives server-locked Arcade")
  ui.show_menu();await process_frame
 cfg=ConfigFile.new();cfg.set_value("flight","aircraft_id","unavailable_future_plane");cfg.set_value("flight","profile",99);cfg.set_value("flight","mode","invalid");cfg.save("user://settings.cfg")
 var other: CanvasLayer=load("res://client/ui.gd").new();other.session=session;other.world=world;parent.add_child(other)
 check(other.select_plane.selected==0 and other.select_profile.selected==2 and other.select_mode.selected==0,"unavailable aircraft/mode and out-of-range profile fall back safely")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"ui_preferences_summary","status":"PASS" if ok else "FAIL","checks":checks,"user_directory":OS.get_user_data_dir(),"scope":"actual rendered desktop UI nodes/config and pending-join cancellation; not phone or public multiplayer acceptance"}))
 parent.queue_free();await process_frame;quit(0 if ok else 1)
