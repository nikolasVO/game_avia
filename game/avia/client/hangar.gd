extends PanelContainer
## Native 3D inspection/comparison. Only playable prototypes can be selected for flight.
signal selected(index: int)
var viewport: SubViewport
var model: Node3D
var model_root: Node3D
var detail: Label
var first: OptionButton
var second: OptionButton
var chart: Control
var dragging: bool=false
var compare: Label
var lang: String="en"
var title: Label
var choose: Button
var close: Button
var country: OptionButton
var aircraft_class: OptionButton
var speed: OptionButton
var agility: OptionButton
var favorites_only: CheckBox
var favorite: Button
var reset: Button
var count: Label
var scroll: ScrollContainer
var favorites: Array[String]=[]
var current_id: String="f16c"
const CLASS_NAMES: Dictionary={"original":["Original","Авторский"],"light_fighter":["Light fighter","Лёгкий истребитель"],"heavy_fighter":["Heavy fighter","Тяжёлый истребитель"],"multirole":["Multirole","Многоцелевой"]}
const COUNTRY_RU: Dictionary={"Game Avia":"Game Avia","USA":"США","Russia":"Россия","France":"Франция","Sweden":"Швеция"}
func _ready() -> void:
 position=Vector2(110,25);size=Vector2(1060,665)
 var bg: StyleBoxFlat=StyleBoxFlat.new();bg.bg_color=Color("10252d");bg.content_margin_left=20;bg.content_margin_right=20;bg.content_margin_top=15;bg.content_margin_bottom=15;add_theme_stylebox_override("panel",bg)
 var outer: VBoxContainer=VBoxContainer.new();outer.add_theme_constant_override("separation",8);add_child(outer)
 title=Label.new();title.text="HANGAR";title.add_theme_font_size_override("font_size",23);outer.add_child(title)
 scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
 var column: VBoxContainer=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
 var filters: HBoxContainer=HBoxContainer.new();column.add_child(filters)
 country=OptionButton.new();aircraft_class=OptionButton.new()
 for control: OptionButton in [country,aircraft_class]:
  control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.custom_minimum_size.y=44;filters.add_child(control);control.item_selected.connect(func(_i: int):_rebuild_list())
 var limits: HBoxContainer=HBoxContainer.new();column.add_child(limits)
 speed=OptionButton.new();agility=OptionButton.new()
 for control: OptionButton in [speed,agility]:
  control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.custom_minimum_size.y=44;limits.add_child(control);control.item_selected.connect(func(_i: int):_rebuild_list())
 favorites_only=CheckBox.new();limits.add_child(favorites_only);favorites_only.toggled.connect(func(_value: bool):_rebuild_list())
 reset=Button.new();limits.add_child(reset);reset.pressed.connect(_reset_filters)
 count=Label.new();count.add_theme_font_size_override("font_size",16);column.add_child(count)
 var row: HBoxContainer=HBoxContainer.new();column.add_child(row)
 first=OptionButton.new();second=OptionButton.new()
 for index: int in AviaFlight.PLANES.size():second.add_item(AviaFlight.PLANES[index].name,index)
 for control: OptionButton in [first,second]:control.clip_text=true;control.custom_minimum_size=Vector2(470,44)
 first.size_flags_horizontal=Control.SIZE_EXPAND_FILL;second.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(first);row.add_child(second)
 second.select(4)
 var content: HBoxContainer=HBoxContainer.new();column.add_child(content)
 var surface: SubViewportContainer=SubViewportContainer.new();surface.custom_minimum_size=Vector2(580,300);surface.stretch=true;content.add_child(surface)
 viewport=SubViewport.new();viewport.size=Vector2i(580,300);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;surface.add_child(viewport)
 model_root=Node3D.new();viewport.add_child(model_root)
 var env: WorldEnvironment=WorldEnvironment.new();var sky: Environment=Environment.new();sky.background_mode=Environment.BG_COLOR;sky.background_color=Color("213d49");sky.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;sky.ambient_light_color=Color("e3ebe6");sky.ambient_light_energy=.7;env.environment=sky;model_root.add_child(env)
 var light: DirectionalLight3D=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-25,0);model_root.add_child(light)
 var floor_mesh: MeshInstance3D=MeshInstance3D.new();var floor_shape: BoxMesh=BoxMesh.new();floor_shape.size=Vector3(40,.2,34);floor_mesh.mesh=floor_shape;floor_mesh.position.y=-1.5
 var mat: StandardMaterial3D=StandardMaterial3D.new();mat.albedo_color=Color("52636b");floor_mesh.material_override=mat;model_root.add_child(floor_mesh)
 var structure: SurfaceTool=SurfaceTool.new();structure.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x: float in [-16.0,16.0]:
  AviaAircraft._box(structure,Vector3(x,3.5,7),Vector3(.4,10,.5),Color("83928d"))
 AviaAircraft._box(structure,Vector3(0,8.3,7),Vector3(33,.4,.6),Color("83928d"))
 for x: float in [-12.0,-6.0,0.0,6.0,12.0]:
  AviaAircraft._box(structure,Vector3(x,-1.38,0),Vector3(.04,.02,30),Color("b9c3ad"))
 AviaAircraft._mesh(structure,model_root,"HangarStructure",0,150)
 var camera: Camera3D=Camera3D.new();model_root.add_child(camera);camera.position=Vector3(11,7,-17);camera.look_at(Vector3.ZERO);camera.fov=44;camera.current=true
 detail=Label.new();detail.custom_minimum_size.x=380;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",16);content.add_child(detail)
 surface.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton:dragging=event.pressed
  if event is InputEventMouseMotion and dragging and model:model.rotate_y(event.relative.x*.009)
  if event is InputEventScreenDrag and model:model.rotate_y(event.relative.x*.009))
 chart=Control.new();chart.custom_minimum_size=Vector2(990,130);column.add_child(chart);chart.draw.connect(_draw_comparison)
 compare=Label.new();compare.add_theme_font_size_override("font_size",16);column.add_child(compare)
 var buttons: HBoxContainer=HBoxContainer.new();outer.add_child(buttons)
 choose=Button.new();choose.text="Select aircraft / Выбрать самолёт";choose.custom_minimum_size.y=52;buttons.add_child(choose);choose.pressed.connect(_choose)
 favorite=Button.new();buttons.add_child(favorite);favorite.pressed.connect(_toggle_favorite)
 close=Button.new();close.text="Back / Назад";buttons.add_child(close);close.pressed.connect(hide)
 first.item_selected.connect(func(_i: int):current_id=str(first.get_item_metadata(first.selected));refresh());second.item_selected.connect(func(_i: int):refresh())
 var cfg: ConfigFile=ConfigFile.new()
 if cfg.load("user://hangar.cfg")==OK:
  var saved: Variant=cfg.get_value("collection","favorites",[])
  if saved is Array or saved is PackedStringArray:
   for id: Variant in saved:
    if id is String and AviaCatalog.index_of(id)>=0 and not favorites.has(id):favorites.append(id)
 localize()
func localize() -> void:
 title.text="АНГАР · ЛЁТНЫЕ ПРОТОТИПЫ" if lang=="ru" else "HANGAR · FLIGHT PROTOTYPES"
 choose.text="Выбрать самолёт" if lang=="ru" else "Select aircraft"
 close.text="Назад" if lang=="ru" else "Back"
 var country_value: String="" if country.item_count==0 else str(country.get_item_metadata(country.selected))
 var class_value: String="" if aircraft_class.item_count==0 else str(aircraft_class.get_item_metadata(aircraft_class.selected))
 country.clear();country.add_item("Все страны" if lang=="ru" else "All countries");country.set_item_metadata(0,"")
 aircraft_class.clear();aircraft_class.add_item("Все классы" if lang=="ru" else "All classes");aircraft_class.set_item_metadata(0,"")
 for spec: Dictionary in AviaFlight.PLANES:
  _add_filter_value(country,str(spec.country),str(COUNTRY_RU.get(spec.country,spec.country)) if lang=="ru" else str(spec.country),country_value)
  var key: String=str(spec["class"])
  var caption: String=str(CLASS_NAMES.get(key,[key,key])[1 if lang=="ru" else 0])
  _add_filter_value(aircraft_class,key,caption,class_value)
 var speed_index: int=maxi(0,speed.selected);var agility_index: int=maxi(0,agility.selected)
 speed.clear();agility.clear()
 for label: String in (["Любая скорость","От 1000 км/ч","От 2000 км/ч"] if lang=="ru" else ["Any speed","At least 1000 km/h","At least 2000 km/h"]):speed.add_item(label)
 for label: String in (["Любая манёвренность","Манёвренность от 85","Манёвренность от 90"] if lang=="ru" else ["Any manoeuvrability","Manoeuvrability 85+","Manoeuvrability 90+"]):agility.add_item(label)
 speed.select(speed_index);agility.select(agility_index)
 favorites_only.text="Избранное" if lang=="ru" else "Favorites"
 reset.text="Сброс" if lang=="ru" else "Reset"
 _rebuild_list()
func _add_filter_value(control: OptionButton,value: String,caption: String,previous: String) -> void:
 for i: int in control.item_count:
  if control.get_item_metadata(i)==value:return
 control.add_item(caption);var index: int=control.item_count-1;control.set_item_metadata(index,value)
 if previous==value:control.select(index)
func _reset_filters() -> void:
 country.select(0);aircraft_class.select(0);speed.select(0);agility.select(0);favorites_only.set_pressed_no_signal(false);_rebuild_list()
func _rebuild_list() -> void:
 first.clear()
 var min_speed: float=[0.0,1000.0,2000.0][maxi(0,speed.selected)]
 var min_agility: float=[0.0,85.0,90.0][maxi(0,agility.selected)]
 for index: int in AviaFlight.PLANES.size():
  var spec: Dictionary=AviaFlight.PLANES[index]
  if country.selected>0 and country.get_item_metadata(country.selected)!=spec.country:continue
  if aircraft_class.selected>0 and aircraft_class.get_item_metadata(aircraft_class.selected)!=spec["class"]:continue
  if float(spec.flight.max_speed_altitude_kmh)<min_speed or float(spec.handling.maneuverability)<min_agility:continue
  if favorites_only.button_pressed and not favorites.has(spec.aircraft_id):continue
  first.add_item(("★ " if favorites.has(spec.aircraft_id) else "")+spec.name,index)
  first.set_item_metadata(first.item_count-1,spec.aircraft_id)
  if spec.aircraft_id==current_id:first.select(first.item_count-1)
 if first.item_count>0:current_id=str(first.get_item_metadata(first.selected))
 count.text=("Показано %d из %d лётных прототипов" if lang=="ru" else "Showing %d of %d flight prototypes") % [first.item_count,AviaFlight.PLANES.size()]
 refresh()
func selected_index() -> int:
 return -1 if first.selected<0 else first.get_selected_id()
func open_for(index: int) -> void:
 if index>=0 and index<AviaFlight.PLANES.size():
  current_id=AviaFlight.PLANES[index].aircraft_id
  _rebuild_list()
  if selected_index()!=index:
   current_id=AviaFlight.PLANES[index].aircraft_id;_reset_filters()
 scroll.scroll_vertical=0;show()
func _choose() -> void:
 var index: int=selected_index()
 if index>=0:selected.emit(index);hide()
func _toggle_favorite() -> void:
 if selected_index()<0:return
 if favorites.has(current_id):favorites.erase(current_id)
 else:favorites.append(current_id)
 # Separate from the menu's cached settings.cfg to avoid lost settings updates.
 var cfg: ConfigFile=ConfigFile.new();cfg.set_value("collection","favorites",favorites)
 if cfg.save("user://hangar.cfg")!=OK:push_warning("Could not save hangar favorites")
 _rebuild_list()
func refresh() -> void:
 if model:model.free();model=null
 var index: int=selected_index()
 choose.disabled=index<0;favorite.disabled=index<0;first.disabled=index<0
 favorite.text=("Убрать ★" if lang=="ru" else "Remove ★") if favorites.has(current_id) else ("В избранное ☆" if lang=="ru" else "Favorite ☆")
 if index<0:
  detail.text="Нет совпадений. Измените фильтры или нажмите «Сброс»." if lang=="ru" else "No matches. Change filters or choose Reset."
  compare.text="";chart.queue_redraw();return
 var spec: Dictionary=AviaFlight.PLANES[index]
 model=AviaAircraft.build(index);model_root.add_child(model);model.rotation.y=-.25
 var f: Dictionary=spec.flight
 var pattern: String="%s\n%s\n\nGAME BALANCE\nSea level: %d km/h\nAltitude speed limit: %d km/h\nStall: %d km/h\nApproach: %d km/h\nAcceleration: %.1f m/s²\nAfterburner: %.1f m/s²\n\nProcedural flight prototype"
 if lang=="ru":pattern="%s\n%s\n\nИГРОВЫЕ ПАРАМЕТРЫ\nУ земли: %d км/ч\nПредел на высоте: %d км/ч\nСваливание: %d км/ч\nПосадка: %d км/ч\nРазгон: %.1f м/с²\nФорсаж: %.1f м/с²\n\nПроцедурный лётный прототип"
 detail.text=pattern % [spec.name,COUNTRY_RU.get(spec.country,spec.country) if lang=="ru" else spec.country,f.max_speed_sea_kmh,f.max_speed_altitude_kmh,f.stall_speed_kmh,f.landing_speed_kmh,f.acceleration_mps2,f.afterburner_acceleration_mps2]
 if not bool(spec.systems.afterburner):
  detail.text=detail.text.replace("Afterburner: %.1f m/s²" % f.afterburner_acceleration_mps2,"Afterburner: unavailable").replace("Форсаж: %.1f м/с²" % f.afterburner_acceleration_mps2,"Форсаж: отсутствует")
 detail.text=detail.text.replace("Procedural flight prototype","Flight prototype · model review pending" if spec.has("visual") else "Original Game Avia aircraft").replace("Процедурный лётный прототип","Лётный прототип · проверка модели не завершена" if spec.has("visual") else "Авторский самолёт Game Avia")
 var card: Dictionary=spec.get("hangar",{})
 if card.has(lang):detail.text+="\n\n"+str(card[lang])
 compare.text="%s  /  %s · %s" % [spec.name,AviaFlight.PLANES[second.get_selected_id()].name,"Вращайте модель" if lang=="ru" else "Drag to rotate"]
 chart.queue_redraw()
func _draw_comparison() -> void:
 if selected_index()<0:return
 var spec_a: Dictionary=AviaFlight.PLANES[selected_index()];var spec_b: Dictionary=AviaFlight.PLANES[second.get_selected_id()]
 var a: Dictionary=spec_a.handling;var b: Dictionary=spec_b.handling
 var font: Font=get_theme_default_font()
 var keys: Array[String]=["maneuverability","stability","inertia","low_speed_control"]
 var captions: Array=["Манёвренность","Устойчивость","Инерция","На малой скорости"] if lang=="ru" else ["Manoeuvrability","Stability","Inertia","Low-speed control"]
 for i: int in keys.size():
  var y: float=i*25
  chart.draw_string(font,Vector2(0,y+17),captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5e5d6"))
  chart.draw_rect(Rect2(305,y,300,8),Color("203640"));chart.draw_rect(Rect2(305,y,3*float(a[keys[i]]),8),Color("dfb66c"))
  chart.draw_rect(Rect2(305,y+11,300,8),Color("203640"));chart.draw_rect(Rect2(305,y+11,3*float(b[keys[i]]),8),Color("74b6bd"))
  chart.draw_string(font,Vector2(630,y+17),"%d / %d" % [a[keys[i]],b[keys[i]]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
 var max_speed: float=1.0
 for spec: Dictionary in AviaFlight.PLANES:max_speed=maxf(max_speed,float(spec.flight.max_speed_altitude_kmh))
 chart.draw_string(font,Vector2(0,117),"Предел на высоте" if lang=="ru" else "Altitude speed limit",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5e5d6"))
 chart.draw_rect(Rect2(305,100,300,8),Color("203640"));chart.draw_rect(Rect2(305,100,300*float(spec_a.flight.max_speed_altitude_kmh)/max_speed,8),Color("dfb66c"))
 chart.draw_rect(Rect2(305,111,300,8),Color("203640"));chart.draw_rect(Rect2(305,111,300*float(spec_b.flight.max_speed_altitude_kmh)/max_speed,8),Color("74b6bd"))
 chart.draw_string(font,Vector2(630,117),("%d / %d км/ч" if lang=="ru" else "%d / %d km/h") % [spec_a.flight.max_speed_altitude_kmh,spec_b.flight.max_speed_altitude_kmh],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
