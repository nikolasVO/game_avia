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
func _ready() -> void:
 position=Vector2(110,25);size=Vector2(1060,665)
 var bg: StyleBoxFlat=StyleBoxFlat.new();bg.bg_color=Color("10252d");bg.content_margin_left=20;bg.content_margin_right=20;bg.content_margin_top=15;bg.content_margin_bottom=15;add_theme_stylebox_override("panel",bg)
 var column: VBoxContainer=VBoxContainer.new();column.add_theme_constant_override("separation",4);add_child(column)
 title=Label.new();title.text="HANGAR";title.add_theme_font_size_override("font_size",23);column.add_child(title)
 var row: HBoxContainer=HBoxContainer.new();column.add_child(row)
 first=OptionButton.new();second=OptionButton.new()
 for spec: Dictionary in AviaFlight.PLANES:first.add_item(spec.name);second.add_item(spec.name)
 first.size_flags_horizontal=Control.SIZE_EXPAND_FILL;second.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(first);row.add_child(second)
 first.select(3);second.select(4)
 var content: HBoxContainer=HBoxContainer.new();column.add_child(content)
 var surface: SubViewportContainer=SubViewportContainer.new();surface.custom_minimum_size=Vector2(620,300);surface.stretch=true;content.add_child(surface)
 viewport=SubViewport.new();viewport.size=Vector2i(620,300);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;surface.add_child(viewport)
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
 detail=Label.new();detail.custom_minimum_size.x=360;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",16);content.add_child(detail)
 surface.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton:dragging=event.pressed
  if event is InputEventMouseMotion and dragging and model:model.rotate_y(event.relative.x*.009)
  if event is InputEventScreenDrag and model:model.rotate_y(event.relative.x*.009))
 chart=Control.new();chart.custom_minimum_size=Vector2(990,105);column.add_child(chart);chart.draw.connect(_draw_comparison)
 compare=Label.new();compare.add_theme_font_size_override("font_size",16);column.add_child(compare)
 var buttons: HBoxContainer=HBoxContainer.new();column.add_child(buttons)
 choose=Button.new();choose.text="Select aircraft / Выбрать самолёт";buttons.add_child(choose);choose.pressed.connect(func():selected.emit(first.selected);hide())
 close=Button.new();close.text="Back / Назад";buttons.add_child(close);close.pressed.connect(hide)
 first.item_selected.connect(func(_i: int):refresh());second.item_selected.connect(func(_i: int):refresh());localize()
func localize() -> void:
 title.text="АНГАР · ЛЁТНЫЕ ПРОТОТИПЫ" if lang=="ru" else "HANGAR · FLIGHT PROTOTYPES"
 choose.text="Выбрать самолёт" if lang=="ru" else "Select aircraft"
 close.text="Назад" if lang=="ru" else "Back"
 refresh()
func refresh() -> void:
 if model:model.free()
 var spec: Dictionary=AviaFlight.PLANES[first.selected]
 model=AviaAircraft.build(first.selected);model_root.add_child(model);model.rotation.y=-.25
 var f: Dictionary=spec.flight
 var pattern: String="%s\n%s\n\nGAME BALANCE\nSea level: %d km/h\nAltitude ceiling: %d km/h\nStall: %d km/h\nApproach: %d km/h\nAcceleration: %.1f m/s²\nAfterburner: %.1f m/s²\n\nProcedural flight prototype"
 if lang=="ru":pattern="%s\n%s\n\nИГРОВЫЕ ПАРАМЕТРЫ\nУ земли: %d км/ч\nПредел на высоте: %d км/ч\nСваливание: %d км/ч\nПосадка: %d км/ч\nРазгон: %.1f м/с²\nФорсаж: %.1f м/с²\n\nПроцедурный лётный прототип"
 detail.text=pattern % [spec.name,spec.country,f.max_speed_sea_kmh,f.max_speed_altitude_kmh,f.stall_speed_kmh,f.landing_speed_kmh,f.acceleration_mps2,f.afterburner_acceleration_mps2]
 compare.text="%s  /  %s · %s" % [spec.name,AviaFlight.PLANES[second.selected].name,"Вращайте модель" if lang=="ru" else "Drag to rotate"]
 chart.queue_redraw()
func _draw_comparison() -> void:
 var a: Dictionary=AviaFlight.PLANES[first.selected].handling;var b: Dictionary=AviaFlight.PLANES[second.selected].handling
 var font: Font=get_theme_default_font()
 var keys: Array[String]=["maneuverability","stability","inertia","low_speed_control"]
 var captions: Array=["Манёвренность","Устойчивость","Инерция","На малой скорости"] if lang=="ru" else ["Manoeuvrability","Stability","Inertia","Low-speed control"]
 for i: int in keys.size():
  var y: float=i*25
  chart.draw_string(font,Vector2(0,y+17),captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5e5d6"))
  chart.draw_rect(Rect2(305,y,300,8),Color("203640"));chart.draw_rect(Rect2(305,y,3*float(a[keys[i]]),8),Color("dfb66c"))
  chart.draw_rect(Rect2(305,y+11,300,8),Color("203640"));chart.draw_rect(Rect2(305,y+11,3*float(b[keys[i]]),8),Color("74b6bd"))
  chart.draw_string(font,Vector2(630,y+17),"%d / %d" % [a[keys[i]],b[keys[i]]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
