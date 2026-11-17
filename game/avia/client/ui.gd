extends CanvasLayer
var session: Node
var world: Node3D
var touch: Control
var menu: PanelContainer
var hud: Label
var notice: Label
var host: LineEdit
var code: LineEdit
var select_plane: OptionButton
var select_mode: OptionButton
var language: String="en"
var private_room: CheckBox
var settings: ConfigFile=ConfigFile.new()
var labels: Dictionary={}
var root: Control
var frame_times: Array[float]=[]
var radar: Control
const TEXT: Dictionary={
 "en":{"title":"TIDAL WINGS","subtitle":"GAME AVIA  ·  NATIVE FLIGHT PROTOTYPE","play":"Join flight","plane":"Aircraft","mode":"Mode","host":"Server address","private":"Private room","code":"Friend code · 4–12 uppercase letters/digits","help":"Shift / Ctrl: throttle  ·  W/S: pitch  ·  A/D: bank
Q/E: rudder  ·  Space: brake  ·  R: recover  ·  F: fire
Touch: left stick, right throttle, upper action. Lift off above 90 km/h.
Land gently on either runway. Gold rings mark the race. Free flight is peaceful.","left":"Left handed","invert":"Invert pitch","assist":"Beginner help","motion":"Reduce camera motion","sound":"Sound","back":"Menu","camera":"Camera","recover":"Recover","brake":"Brake"},
 "ru":{"title":"ПРИЛИВНЫЕ КРЫЛЬЯ","subtitle":"GAME AVIA  ·  ПРОТОТИП НАТИВНОЙ ИГРЫ","play":"Начать полёт","plane":"Самолёт","mode":"Режим","host":"Адрес сервера","private":"Приватная комната","code":"Код друзей · 4–12 заглавных букв/цифр","help":"Shift / Ctrl: тяга  ·  W/S: тангаж  ·  A/D: крен
Q/E: руль  ·  Пробел: тормоз  ·  R: восстановить  ·  F: огонь
Касания: слева джойстик, справа тяга, выше действие. Взлёт от 90 км/ч.
Садитесь плавно на полосу. Золотые кольца — гонка. Свободный полёт мирный.","left":"Для левшей","invert":"Инверсия тангажа","assist":"Помощь новичку","motion":"Меньше движения камеры","sound":"Звук","back":"Меню","camera":"Камера","recover":"Восстановить","brake":"Тормоз"}}
func tr_text(key: String) -> String:return str(TEXT[language].get(key,key))
func _ready() -> void:
 settings.load("user://settings.cfg")
 language=str(settings.get_value("ui","language","en"))
 if not TEXT.has(language):language="en"
 var theme: Theme=Theme.new();theme.default_font_size=21
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=theme;root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 touch=load("res://client/touch.gd").new();root.add_child(touch);touch.visible=false
 radar=load("res://client/radar.gd").new();radar.session=session;radar.position=Vector2(1060,100);radar.size=Vector2(170,170);root.add_child(radar)
 var sound: AudioStreamPlayer=load("res://client/sound.gd").new();sound.session=session;add_child(sound)
 var safe: MarginContainer=MarginContainer.new();safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Leave gesture margins; device-specific safe area is applied below.
 var margins: Vector4i=Vector4i(28,20,28,20)
 if DisplayServer.get_name()!="headless":
  var area: Rect2i=DisplayServer.get_display_safe_area();var screen: Vector2i=DisplayServer.screen_get_size()
  if area.size.x>0 and screen.x>0:
   margins.x=maxi(28,int(float(area.position.x)*1280/screen.x));margins.z=maxi(28,int(float(screen.x-area.end.x)*1280/screen.x))
 for i: int in range(4):safe.add_theme_constant_override(["margin_left","margin_top","margin_right","margin_bottom"][i],margins[i])
 safe.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(safe)
 var layout: VBoxContainer=VBoxContainer.new();layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;safe.add_child(layout)
 var top: HBoxContainer=HBoxContainer.new();layout.add_child(top)
 hud=Label.new();hud.add_theme_color_override("font_color",Color("fff0cd"));hud.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(hud)
 for action: String in ["back","camera","recover"]:
  var b: Button=Button.new();b.text=tr_text(action);labels[action]=b;top.add_child(b)
  match action:
   "back":b.pressed.connect(show_menu)
   "camera":b.pressed.connect(func():world.cockpit=not world.cockpit)
   "recover":b.pressed.connect(func():touch.respawn=true)
 var brake_button: Button=Button.new();brake_button.text=tr_text("brake");labels.brake=brake_button;top.add_child(brake_button)
 brake_button.button_down.connect(func():touch.brake=true);brake_button.button_up.connect(func():touch.brake=false)
 notice=Label.new();notice.add_theme_font_size_override("font_size",19);layout.add_child(notice)
 menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.position=Vector2(260,55);menu.size=Vector2(760,610);root.add_child(menu)
 var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(0.06,0.14,0.18,0.95);style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=20;style.content_margin_bottom=20;menu.add_theme_stylebox_override("panel",style)
 var col: VBoxContainer=VBoxContainer.new();col.add_theme_constant_override("separation",10);menu.add_child(col)
 for key: String in ["title","subtitle"]:
  var label: Label=Label.new();label.text=tr_text(key);label.add_theme_font_size_override("font_size",38 if key=="title" else 16);col.add_child(label);labels[key]=label
 var row: HBoxContainer=HBoxContainer.new();col.add_child(row)
 select_plane=OptionButton.new();select_plane.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for spec: Dictionary in AviaFlight.PLANES:select_plane.add_item(spec.name)
 row.add_child(select_plane)
 select_mode=OptionButton.new();select_mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for mode_name: String in ["Free flight / Полёт","Race / Гонка","Air combat / Бой"]:select_mode.add_item(mode_name)
 row.add_child(select_mode)
 host=LineEdit.new();host.placeholder_text=tr_text("host");host.text=str(settings.get_value("net","host","127.0.0.1"));col.add_child(host)
 var room_row: HBoxContainer=HBoxContainer.new();col.add_child(room_row)
 private_room=CheckBox.new();private_room.text=tr_text("private");labels.private=private_room;room_row.add_child(private_room)
 code=LineEdit.new();code.placeholder_text=tr_text("code");code.max_length=12;code.size_flags_horizontal=Control.SIZE_EXPAND_FILL;room_row.add_child(code)
 var controls_row: HBoxContainer=HBoxContainer.new();col.add_child(controls_row)
 for key: String in ["left","invert","assist","motion","sound"]:
  var check: CheckBox=CheckBox.new();check.text=tr_text(key);check.button_pressed=bool(settings.get_value("controls",key,key in ["assist","sound"]));labels[key]=check;controls_row.add_child(check)
  check.toggled.connect(func(value: bool):_option(key,value))
  _option(key,check.button_pressed)
 var sensitivity: HSlider=HSlider.new();sensitivity.min_value=0.3;sensitivity.max_value=1.5;sensitivity.step=0.05;sensitivity.value=float(settings.get_value("controls","sensitivity",1.0));col.add_child(sensitivity);touch.sensitivity=sensitivity.value
 sensitivity.value_changed.connect(func(value: float):touch.sensitivity=value;settings.set_value("controls","sensitivity",value);settings.save("user://settings.cfg"))
 var help: Label=Label.new();help.text=tr_text("help");help.add_theme_font_size_override("font_size",18);labels.help=help;col.add_child(help)
 var bottom: HBoxContainer=HBoxContainer.new();col.add_child(bottom)
 var play: Button=Button.new();play.text=tr_text("play");labels.play=play;play.size_flags_horizontal=Control.SIZE_EXPAND_FILL;play.custom_minimum_size.y=56;bottom.add_child(play);play.pressed.connect(join)
 var lang: Button=Button.new();lang.text="EN / RU";bottom.add_child(lang);lang.pressed.connect(func():language="ru" if language=="en" else "en";settings.set_value("ui","language",language);settings.save("user://settings.cfg");_translate())
func _option(key: String,value: bool) -> void:
 match key:
  "left":touch.left_handed=value
  "invert":touch.invert=value
  "assist":touch.assistance=value
  "motion":world.reduced_motion=value
  "sound":AudioServer.set_bus_mute(0,not value)
 settings.set_value("controls",key,value);settings.save("user://settings.cfg")
func _translate() -> void:
 for key: String in labels:labels[key].text=tr_text(key)
 code.placeholder_text=tr_text("code");host.placeholder_text=tr_text("host")
func join() -> void:
 settings.set_value("net","host",host.text.strip_edges());settings.save("user://settings.cfg")
 var result: Error=session.connect_to(host.text.strip_edges(),24567,{"plane":select_plane.selected,"mode":["free","race","pvp"][select_mode.selected],"private":private_room.button_pressed,"code":code.text.strip_edges().to_upper()})
 if result==OK:menu.hide();touch.show()
func show_menu() -> void:
 session.disconnect_session();touch.clear_pointers();touch.throttle=0;touch.hide();menu.show()
func _process(delta: float) -> void:
 frame_times.append(delta*1000)
 if frame_times.size()>54000:frame_times.pop_front()
 if not session.joined or session.local_state.is_empty():hud.text=session.status;notice.text="";return
 var s: Dictionary=session.local_state
 var warning: String=""
 if s.crashed:warning="CRASH — R / Recover" if language=="en" else "АВАРИЯ — Восстановить"
 elif s.v.length()<float(AviaFlight.PLANES[s.plane].stall) and not s.grounded:warning="LOW AIRSPEED" if language=="en" else "МАЛАЯ СКОРОСТЬ"
 hud.text="%03d km/h   %04d m ASL   %03d°   %d%%   ♥ %d   %s   %d pilots" % [s.v.length()*3.6,s.p.y,fposmod(rad_to_deg(-float(s.yaw)),360),float(session.controls.throttle)*100,s.health,session.mode,session.others.size()+1]
 notice.text=warning+"
"+(session.notices[-1] if not session.notices.is_empty() else session.room)
 touch.queue_redraw()
