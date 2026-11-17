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
var speed_unit: int=0
var altitude_unit: int=0
var advanced_hud: bool=false
var hangar: PanelContainer
var system_buttons: Dictionary={}
var select_profile: OptionButton
var select_mode: OptionButton
var language: String="en"
var private_room: CheckBox
var settings: ConfigFile=ConfigFile.new()
var labels: Dictionary={}
var root: Control
var frame_times: Array[float]=[]
var last_frame_us: int=0
var frame_cursor: int=0
var status_label: Label
var top_buttons: Array[Button]=[]
var radar: Control
const TEXT: Dictionary={
 "en":{"title":"TIDAL WINGS","subtitle":"GAME AVIA  ·  NATIVE FLIGHT PROTOTYPE","play":"Join flight","plane":"Aircraft","mode":"Mode","host":"Server address","private":"Private room","code":"Friend code · 4–12 uppercase letters/digits","help":"Shift / Ctrl: throttle  ·  W/S: pitch  ·  A/D: bank
Q/E: rudder  ·  Space: brake  ·  R: recover  ·  F: fire
Touch: left stick, right throttle, upper brake (fire in combat). Lift off above 90 km/h.
Land gently on either runway. Gold rings mark the race. Free flight is peaceful.","left":"Left handed","invert":"Invert pitch","assist":"Beginner help","motion":"Reduce camera motion","sound":"Sound","back":"Menu","camera":"Camera","recover":"Recover","brake":"Brake"},
 "ru":{"title":"ПРИЛИВНЫЕ КРЫЛЬЯ","subtitle":"GAME AVIA  ·  ПРОТОТИП НАТИВНОЙ ИГРЫ","play":"Начать полёт","plane":"Самолёт","mode":"Режим","host":"Адрес сервера","private":"Приватная комната","code":"Код друзей · 4–12 заглавных букв/цифр","help":"Shift / Ctrl: тяга  ·  W/S: тангаж  ·  A/D: крен
Q/E: руль  ·  Пробел: тормоз  ·  R: восстановить  ·  F: огонь
Касания: слева джойстик, справа тяга, выше тормоз (огонь в бою). Взлёт от 90 км/ч.
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
  var b: Button=Button.new();b.text=tr_text(action);labels[action]=b;top.add_child(b);top_buttons.append(b)
  match action:
   "back":b.pressed.connect(show_menu)
   "camera":b.pressed.connect(func():world.cockpit=not world.cockpit)
   "recover":b.pressed.connect(func():touch.respawn=true)
 var brake_button: Button=Button.new();brake_button.text=tr_text("brake");labels.brake=brake_button;top.add_child(brake_button);top_buttons.append(brake_button)
 brake_button.button_down.connect(func():touch.brake=true);brake_button.button_up.connect(func():touch.brake=false)
 notice=Label.new();notice.add_theme_font_size_override("font_size",19);layout.add_child(notice)
 menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);menu.position=Vector2(160,40);menu.size=Vector2(960,640);root.add_child(menu)
 var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(0.06,0.14,0.18,0.95);style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=20;style.content_margin_bottom=20;menu.add_theme_stylebox_override("panel",style)
 var scroll: ScrollContainer=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu.add_child(scroll)
 var col: VBoxContainer=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",8);scroll.add_child(col)
 for key: String in ["title","subtitle"]:
  var label: Label=Label.new();label.text=tr_text(key);label.add_theme_font_size_override("font_size",38 if key=="title" else 16);col.add_child(label);labels[key]=label
 status_label=Label.new();status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.add_theme_color_override("font_color",Color("efcd8b"));status_label.hide();col.add_child(status_label)
 var row: HBoxContainer=HBoxContainer.new();col.add_child(row)
 select_plane=OptionButton.new();select_plane.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for spec: Dictionary in AviaFlight.PLANES:select_plane.add_item(spec.name)
 row.add_child(select_plane)
 select_mode=OptionButton.new();select_mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for mode_name: String in ["Free flight / Полёт","Race / Гонка","Air combat / Бой"]:select_mode.add_item(mode_name)
 row.add_child(select_mode)
 select_profile=OptionButton.new()
 for label: String in ["Arcade / Аркада","Realistic / Реализм","Expert / Эксперт"]:select_profile.add_item(label)
 col.add_child(select_profile)
 var systems_row: HBoxContainer=HBoxContainer.new();systems_row.position=Vector2(380,630);root.add_child(systems_row)
 for label: String in ["AB / Форсаж","Flaps / Закрылки","Gear / Шасси"]:
  var system: CheckBox=CheckBox.new();system.text=label;system.button_pressed=label.begins_with("Gear");systems_row.add_child(system);system_buttons[label]=system
  system.toggled.connect(func(value: bool):
   if label.begins_with("AB"):touch.afterburner=value
   elif label.begins_with("Flaps"):touch.flaps=value
   else:touch.gear=value)
 host=LineEdit.new();host.placeholder_text=tr_text("host");host.text=str(settings.get_value("net","host","127.0.0.1"));col.add_child(host)
 var room_row: HBoxContainer=HBoxContainer.new();col.add_child(room_row)
 private_room=CheckBox.new();private_room.text=tr_text("private");labels.private=private_room;room_row.add_child(private_room)
 code=LineEdit.new();code.placeholder_text=tr_text("code");code.max_length=12;code.size_flags_horizontal=Control.SIZE_EXPAND_FILL;room_row.add_child(code)
 var controls_row: HBoxContainer=HBoxContainer.new();col.add_child(controls_row)
 for key: String in ["left","invert","assist","motion","sound"]:
  if key=="motion":controls_row=HBoxContainer.new();col.add_child(controls_row)
  var check: CheckBox=CheckBox.new();check.text=tr_text(key);check.button_pressed=bool(settings.get_value("controls",key,key in ["assist","sound"]));labels[key]=check;controls_row.add_child(check)
  check.toggled.connect(func(value: bool):_option(key,value))
  _option(key,check.button_pressed)
 var display_row: HBoxContainer=HBoxContainer.new();col.add_child(display_row)
 var speed_choice: OptionButton=OptionButton.new();speed_choice.add_item("km/h / км/ч");speed_choice.add_item("knots / узлы");display_row.add_child(speed_choice)
 speed_unit=int(settings.get_value("ui","speed_unit",0));speed_choice.select(speed_unit)
 speed_choice.item_selected.connect(func(value: int):speed_unit=value;settings.set_value("ui","speed_unit",value);settings.save("user://settings.cfg"))
 var altitude_choice: OptionButton=OptionButton.new();altitude_choice.add_item("m ASL / м над морем");altitude_choice.add_item("ft ASL / футы над морем");display_row.add_child(altitude_choice)
 altitude_unit=int(settings.get_value("ui","altitude_unit",0));altitude_choice.select(altitude_unit)
 altitude_choice.item_selected.connect(func(value: int):altitude_unit=value;settings.set_value("ui","altitude_unit",value);settings.save("user://settings.cfg"))
 var hud_choice: CheckBox=CheckBox.new();hud_choice.text="Advanced HUD / Расширенный HUD";display_row.add_child(hud_choice)
 advanced_hud=bool(settings.get_value("ui","advanced_hud",false));hud_choice.button_pressed=advanced_hud
 hud_choice.toggled.connect(func(value: bool):advanced_hud=value;settings.set_value("ui","advanced_hud",value);settings.save("user://settings.cfg"))
 var quality: OptionButton=OptionButton.new();quality.add_item("30 FPS · Low / Низкое");quality.add_item("60 FPS · Standard / Обычное")
 quality.select(int(settings.get_value("controls","quality",0 if OS.has_feature("mobile") else 1)));col.add_child(quality)
 _quality(quality.selected);quality.item_selected.connect(_quality)
 var sensitivity: HSlider=HSlider.new();sensitivity.min_value=0.3;sensitivity.max_value=1.5;sensitivity.step=0.05;sensitivity.value=float(settings.get_value("controls","sensitivity",1.0));col.add_child(sensitivity);touch.sensitivity=sensitivity.value
 sensitivity.value_changed.connect(func(value: float):touch.sensitivity=value;settings.set_value("controls","sensitivity",value);settings.save("user://settings.cfg"))
 var help: Label=Label.new();help.text=tr_text("help");help.add_theme_font_size_override("font_size",16);labels.help=help;col.add_child(help)
 var bottom: HBoxContainer=HBoxContainer.new();col.add_child(bottom)
 var play: Button=Button.new();play.text=tr_text("play");labels.play=play;play.size_flags_horizontal=Control.SIZE_EXPAND_FILL;play.custom_minimum_size.y=56;bottom.add_child(play);play.pressed.connect(join)
 hangar=load("res://client/hangar.gd").new();hangar.lang=language;root.add_child(hangar);hangar.hide();hangar.selected.connect(func(index: int):select_plane.select(index))
 var hangar_button: Button=Button.new();hangar_button.text="Hangar / Ангар";bottom.add_child(hangar_button);hangar_button.pressed.connect(func():hangar.show())
 var lang: Button=Button.new();lang.text="EN / RU";bottom.add_child(lang);lang.pressed.connect(func():language="ru" if language=="en" else "en";settings.set_value("ui","language",language);settings.save("user://settings.cfg");_translate())
func _quality(index: int) -> void:
 Engine.max_fps=30 if index==0 else 60
 world.camera.far=3500 if index==0 else 6500
 world.get_viewport().scaling_3d_scale=0.7 if index==0 else 1.0
 settings.set_value("controls","quality",index);settings.save("user://settings.cfg")
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
 if hangar:hangar.lang=language;hangar.localize()
 code.placeholder_text=tr_text("code");host.placeholder_text=tr_text("host")
func join() -> void:
 if host.text.strip_edges().is_empty():session.status="Enter a server address";return
 settings.set_value("net","host",host.text.strip_edges());settings.save("user://settings.cfg")
 var result: Error=session.connect_to(host.text.strip_edges(),24567,{"plane":select_plane.selected,"profile":select_profile.selected,"mode":["free","race","pvp"][select_mode.selected],"private":private_room.button_pressed,"code":code.text.strip_edges().to_upper()})
 if result==OK:menu.hide();touch.show()
 else:session.disconnect_session("Connection failed — check server address")
func show_menu() -> void:
 session.disconnect_session();touch.clear_pointers();touch.throttle=0;touch.hide();menu.show()
func _process(delta: float) -> void:
 var now: int=Time.get_ticks_usec()
 if last_frame_us>0:
  var interval: float=float(now-last_frame_us)/1000.0
  if frame_times.size()<108000:frame_times.append(interval)
  else:frame_times[frame_cursor]=interval;frame_cursor=(frame_cursor+1) % 108000
 last_frame_us=now
 if session.status=="Joining" and Time.get_ticks_msec()-session.last_snapshot_ms>8000:session.disconnect_session("Admission timeout — retry from menu")
 for label: String in system_buttons:
  var key: String="afterburner" if label.begins_with("AB") else "flaps" if label.begins_with("Flaps") else "gear"
  system_buttons[label].set_pressed_no_signal(touch.get(key));system_buttons[label].visible=session.joined and int(session.local_state.get("plane",0))>=3
 for button: Button in top_buttons:button.disabled=not session.joined
 touch.combat=session.mode=="pvp"
 touch.action_label=("FIRE" if language=="en" else "ОГОНЬ") if touch.combat else ("BRAKE" if language=="en" else "ТОРМОЗ")
 status_label.visible=session.status not in ["Menu","Connected","Connecting","Joining"]
 status_label.text=connection_text(session.status)
 if not session.joined or session.local_state.is_empty():
  hud.text=connection_text(session.status);notice.text=""
  if session.status not in ["Connecting","Joining"] and not menu.visible:
   touch.clear_pointers();touch.throttle=0;touch.hide();menu.show()
  radar.queue_redraw()
  return
 var s: Dictionary=session.local_state
 var warning: String=""
 if s.crashed:warning="CRASH — R / Recover" if language=="en" else "АВАРИЯ — Восстановить"
 elif s.v.length()<float(AviaFlight.PLANES[s.plane].stall) and not s.grounded:warning="LOW AIRSPEED" if language=="en" else "МАЛАЯ СКОРОСТЬ"
 var mode_label: String={"free":"Free flight" if language=="en" else "Полёт","race":"Race" if language=="en" else "Гонка","pvp":"Combat" if language=="en" else "Бой"}.get(session.mode,session.mode)
 var speed: float=s.v.length()*(3.6 if speed_unit==0 else 1.943844)
 var altitude: float=float(s.p.y)*(1.0 if altitude_unit==0 else 3.28084)
 hud.text="%03d %s  %04d %s ASL  %d%%  ♥ %d" % [speed,"km/h" if speed_unit==0 else "kt",altitude,"m" if altitude_unit==0 else "ft",float(session.controls.throttle)*100,s.health]
 if advanced_hud:hud.text+="  %03d°  ↑%.1f %s/s  %s  %d" % [fposmod(rad_to_deg(-float(s.yaw)),360),float(s.v.y)*(1.0 if altitude_unit==0 else 3.28084),"m" if altitude_unit==0 else "ft",mode_label,session.others.size()+1]
 var remaining: float=5500.0-Vector2(s.p.x,s.p.z).length()
 if remaining<650.0:
  warning=("WORLD EDGE · turn toward the island · %d m" if language=="en" else "ГРАНИЦА МИРА · поверните к острову · %d м") % maxi(0,int(remaining))
 elif s.p.y>2250:
  warning=("ALTITUDE LIMIT · descend · %d m" if language=="en" else "ПРЕДЕЛ ВЫСОТЫ · снижайтесь · %d м") % maxi(0,int(2500-s.p.y))
 var objective: String="Free flight · land on either runway" if language=="en" else "Свободный полёт · посадите самолёт на полосу"
 if session.mode=="race":
  var next: int=int(session.local_race.get("next",0))
  objective=("Checkpoint %d / 5" if language=="en" else "Точка %d / 5") % mini(next+1,5)
  if next>=5:objective=("Finished: %.2f s · Recover to retry" if language=="en" else "Финиш: %.2f с · Восстановить для повтора") % float(session.local_race.get("time",0))
 elif session.mode=="pvp":objective=("Combat · score %d · F / upper touch to fire" if language=="en" else "Бой · счёт %d · F / верхнее касание — огонь") % session.local_score
 var ping: float=session.peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
 notice.text=warning+"\n"+objective+"   %d ms" % ping
 radar.queue_redraw()
 touch.queue_redraw()

func connection_text(value: String) -> String:
 if language=="en":return value
 return {"Enter a server address":"Введите адрес сервера.","Connection failed — check server address":"Не удалось подключиться. Проверьте адрес сервера.","Admission timeout — retry from menu":"Сервер не подтвердил вход. Повторите подключение.","Menu":"Меню","Connecting":"Подключение…","Joining":"Вход в комнату…","Connected":"Подключено","Paused — reconnect from menu":"Игра свёрнута. Подключитесь заново кнопкой «Начать полёт».","Network timeout — retry from menu":"Нет ответа сервера. Проверьте сеть и повторите вход.","Disconnected — retry from menu":"Соединение разорвано. Повторите вход или смените сервер.","Version mismatch":"Версия игры отличается от сервера. Обновите клиент.","Room full":"Комната заполнена. Выберите другую комнату.","Room mode mismatch":"Режим приватной комнаты отличается. Выберите верный режим.","Invalid room code":"Неверный код комнаты.","Private code needs 4–12 uppercase letters/digits":"Для приватной комнаты нужен код из 4–12 заглавных букв или цифр."}.get(value,value)
