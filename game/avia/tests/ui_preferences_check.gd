extends SceneTree
## Real UI restoration/option application in an isolated user directory.
var checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 if not OS.get_user_data_dir().get_file().begins_with("game-avia-ui-check-"):
  push_error("Use tools/ui_preferences_check.py: isolated test user directory required");quit(2);return
 var cfg: ConfigFile=ConfigFile.new()
 cfg.set_value("flight","aircraft_id","su27");cfg.set_value("flight","profile",2);cfg.set_value("flight","mode","pvp");cfg.save("user://settings.cfg")
 var parent: Node=Node.new();root.add_child(parent)
 var session: Node=load("res://net/session.gd").new();session.name="Session";parent.add_child(session)
 var world: Node3D=load("res://client/world.gd").new();parent.add_child(world)
 var ui: CanvasLayer=load("res://client/ui.gd").new();ui.session=session;ui.world=world;parent.add_child(ui)
 check(ui.select_plane.selected==4 and ui.select_profile.selected==2 and ui.select_mode.selected==2,"actual UI restores stable Su27 ID and profile/mode")
 ui.apply_connection_options({"plane":3,"profile":1,"mode":"race","connect":"127.0.0.1"})
 check(ui.select_plane.selected==3 and ui.select_profile.selected==1 and ui.select_mode.selected==1,"direct admission options agree with retry menu")
 ui.show_menu();await process_frame;await process_frame
 check(ui.select_plane.selected==3 and not ui.hud.visible and not ui.radar.visible and ui.top_buttons.all(func(b: Button):return not b.visible),"menu retains selection and hides flight-only HUD/buttons/radar")
 # Calling the actual join path saves preferences before asynchronous model preparation.
 ui.join()
 var saved: ConfigFile=ConfigFile.new();saved.load("user://settings.cfg")
 check(saved.get_value("flight","aircraft_id","")=="f16c" and saved.get_value("flight","profile",-1)==1 and saved.get_value("flight","mode","")=="race","actual join persists aircraft ID rather than mutable catalog index")
 # Cancel the pending preparation; it must not create a late transport.
 ui.show_menu();await process_frame;await process_frame
 check(not session.joined and session.peer==null and not ui.preparing and ui.menu.visible,"cancelled preparation keeps a usable retry menu")
 cfg=ConfigFile.new();cfg.set_value("flight","aircraft_id","unavailable_future_plane");cfg.set_value("flight","profile",99);cfg.set_value("flight","mode","invalid");cfg.save("user://settings.cfg")
 var other: CanvasLayer=load("res://client/ui.gd").new();other.session=session;other.world=world;parent.add_child(other)
 check(other.select_plane.selected==0 and other.select_profile.selected==2 and other.select_mode.selected==0,"unavailable aircraft/mode and out-of-range profile fall back safely")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"ui_preferences_summary","status":"PASS" if ok else "FAIL","checks":checks,"user_directory":OS.get_user_data_dir(),"scope":"actual rendered desktop UI nodes/config and pending-join cancellation; not phone or multiplayer acceptance"}))
 parent.queue_free();await process_frame;quit(0 if ok else 1)
