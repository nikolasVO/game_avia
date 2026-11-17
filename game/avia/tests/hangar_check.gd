extends SceneTree
## Rendered collection regression; never use the owner's preference directory.
var checks: Array[Dictionary]=[]
var emitted: int=-1
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func pick_filter(control: OptionButton,value: String) -> void:
 for i: int in control.item_count:
  if control.get_item_metadata(i)==value:
   control.select(i);control.item_selected.emit(i);return
 check(false,"missing filter "+value)
func rows(h: PanelContainer) -> Array[String]:
 var result: Array[String]=[]
 for i: int in h.first.item_count:result.append(str(h.first.get_item_metadata(i)))
 return result
func settle() -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name: String) -> void:
 await settle()
 var err: Error=root.get_texture().get_image().save_png(OS.get_environment("AVIA_UI_CAPTURE_DIR")+"/"+name+".png")
 check(err==OK,"render capture "+name)
func _run() -> void:
 if not OS.get_user_data_dir().get_file().begins_with("game-avia-ui-check-") or DisplayServer.get_name()=="headless":
  push_error("Use tools/ui_preferences_check.py --hangar with an actual renderer and isolated preferences");quit(2);return
 root.size=Vector2i(1280,720)
 var cfg: ConfigFile=ConfigFile.new();cfg.set_value("flight","aircraft_id","su35s");cfg.set_value("controls","sound",false);cfg.save("user://settings.cfg")
 var collection: ConfigFile=ConfigFile.new();collection.set_value("collection","favorites",["gripen","gripen","f14",9,"removed"]);collection.save("user://hangar.cfg")
 var parent: Node=Node.new();parent.name="Avia";root.add_child(parent)
 var session: Node=load("res://net/session.gd").new();session.name="Session";parent.add_child(session)
 var world: Node3D=load("res://client/world.gd").new();parent.add_child(world)
 var ui: CanvasLayer=load("res://client/ui.gd").new();ui.session=session;ui.world=world;parent.add_child(ui)
 var h: PanelContainer=ui.hangar;h.selected.connect(func(index: int):emitted=index)
 h.open_for(ui.select_plane.selected);await settle()
 check(h.selected_index()==6 and h.current_id=="su35s","opening follows menu aircraft stable ID")
 check(h.favorites==["gripen"],"saved favorites discard duplicates, unavailable IDs and invalid types")
 check(rows(h).size()==9 and not rows(h).has("f14") and h.second.item_count==9,"both selectors retain nine playable prototypes; no planned aircraft exposed")
 pick_filter(h.country,"Russia")
 check(rows(h)==["su27","su35s"] and h.selected_index()==6,"country filtering preserves selected stable ID")
 pick_filter(h.aircraft_class,"heavy_fighter");h.agility.select(2);h.agility.item_selected.emit(2)
 check(rows(h)==["su35s"] and h.first.selected==0 and h.selected_index()==6,"combined class/agility filters map row zero to catalog index six")
 h.favorite.pressed.emit()
 var saved: ConfigFile=ConfigFile.new();saved.load("user://hangar.cfg")
 check(saved.get_value("collection","favorites",[])==["gripen","su35s"],"favorite button persists stable IDs")
 var reloaded: PanelContainer=load("res://client/hangar.gd").new();root.add_child(reloaded)
 check(reloaded.favorites==["gripen","su35s"],"new hangar instance restores persisted favorite IDs")
 reloaded.queue_free();await process_frame
 h.choose.pressed.emit()
 check(emitted==6 and ui.select_plane.selected==6 and not h.visible,"filtered actual Select signal updates menu with Su35, not row zero")
 h.open_for(8);await settle()
 check(h.current_id=="gripen" and h.selected_index()==8 and h.country.selected==0,"opening another menu aircraft clears excluding filters")
 h.favorites_only.button_pressed=true
 check(rows(h)==["su35s","gripen"] and h.selected_index()==8,"favorites filter intersects available catalog and retains selected Gripen")
 h.favorite.pressed.emit()
 check(rows(h)==["su35s"] and h.current_id=="su35s","removing selected favorite safely selects remaining result")
 h.favorite.pressed.emit();await settle()
 check(h.first.item_count==0 and h.selected_index()==-1 and h.model==null and h.choose.disabled and h.favorite.disabled and h.detail.text.contains("No matches"),"empty favorites clears model and disables actions")
 emitted=-1;h._choose();check(emitted==-1,"empty results cannot emit an aircraft selection")
 await capture("hangar-empty")
 h.reset.pressed.emit();pick_filter(h.country,"France");h.speed.select(2);h.speed.item_selected.emit(2);h.agility.select(2);h.agility.item_selected.emit(2)
 check(rows(h)==["rafale"] and h.selected_index()==7,"inclusive 2000 km/h and 90 agility boundaries retain Rafale")
 h.second.select(5);h.second.item_selected.emit(5)
 check(h.compare.text.contains("F-15C") and h.detail.text.contains("balanced multirole"),"filtered comparison and authored English handling card use correct aircraft")
 await capture("hangar-en")
 h.lang="ru";h.localize();await settle()
 check(rows(h)==["rafale"] and h.selected_index()==7 and h.country.get_item_metadata(h.country.selected)=="France" and h.speed.selected==2 and h.agility.selected==2,"translation preserves all filter identities and thresholds")
 check(h.detail.text.contains("Сбалансированный") and h.country.text=="Франция" and h.title.text.contains("АНГАР"),"Russian flight card and country caption are localized")
 await capture("hangar-ru")
 h.scroll.scroll_vertical=10000;await settle()
 check(h.get_global_rect().end.y<=720 and h.choose.get_global_rect().end.y<=h.get_global_rect().end.y and h.close.get_global_rect().end.x<=h.get_global_rect().end.x,"scrolling content keeps Select and Back pinned inside viewport")
 check(h.chart.get_global_rect().intersects(h.scroll.get_global_rect()),"scrolled comparison chart is reachable")
 await capture("hangar-comparison")
 h.reset.pressed.emit();pick_filter(h.aircraft_class,"original");h.speed.select(1);h.speed.item_selected.emit(1)
 check(h.first.item_count==0,"mutually exclusive speed/class filters return empty safely")
 h.reset.pressed.emit();check(rows(h).size()==9 and not h.choose.disabled,"Reset restores playable list from empty filters")
 for i: int in AviaFlight.PLANES.size():
  h.open_for(i)
  check(h.selected_index()==i and h.detail.text.contains(AviaFlight.PLANES[i].name) and not str(AviaFlight.PLANES[i].get("hangar",{}).get("ru","")).is_empty(),"all playable cards and stable selection "+AviaFlight.PLANES[i].aircraft_id)
 h.open_for(0);check(h.detail.text.contains("Форсаж: отсутствует"),"original aircraft card does not advertise an unsupported afterburner")
 saved=ConfigFile.new();saved.load("user://settings.cfg")
 check(saved.get_value("flight","aircraft_id","")=="su35s","collection writes preserve menu settings file")
 collection=ConfigFile.new();collection.set_value("collection","favorites",42);collection.save("user://hangar.cfg")
 var restored: PanelContainer=load("res://client/hangar.gd").new();root.add_child(restored)
 check(restored.favorites.is_empty(),"malformed favorite collection falls back safely")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"hangar_summary","status":"PASS" if ok else "FAIL","checks":checks,"scope":"actual rendered desktop UI/config/selector signals; not phone input, production aircraft or public multiplayer acceptance"}))
 restored.queue_free();parent.queue_free();await process_frame;quit(0 if ok else 1)
