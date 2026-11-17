extends Node
var session: Node
var world: Node3D
var ui: CanvasLayer
var bot: bool=false
var duration: float=0
var elapsed: float=0
var options: Dictionary={}
var captured: bool=false
var headless: bool=false
var quitting: bool=false
var control_focused: bool=true
func _ready() -> void:
 # Debug APK only: reproducible emulator diagnostics, never included in release settings.
 if OS.is_debug_build() and OS.has_feature("android"):
  var diagnostic: ConfigFile=ConfigFile.new()
  if diagnostic.load("user://diagnostics.cfg")==OK:
   for key: String in ["connect","port","duration","bot","diagnostics","disable3d"]:
    if diagnostic.has_section_key("run",key):options[key]=str(diagnostic.get_value("run",key))
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--"):
   var pair: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
   options[pair[0]]=pair[1] if pair.size()>1 else "true"
 session=load("res://net/session.gd").new();session.name="Session";session.diagnostics=options.has("diagnostics");add_child(session)
 headless=DisplayServer.get_name()=="headless"
 duration=float(options.get("duration","0"));bot=options.has("bot")
 if options.has("server"):
  if options.has("stats"):session.stats_path=options.stats
  var result: Error=session.start_server(int(options.get("port","24567")))
  if result!=OK:push_error("Server bind failed "+str(result));get_tree().quit(1)
 else:
  if not headless:
   if options.has("disable3d"):get_viewport().disable_3d=true
   world=load("res://client/world.gd").new();add_child(world)
   ui=load("res://client/ui.gd").new();ui.session=session;ui.world=world;add_child(ui)
   if options.has("hangar"):ui.hangar.show()
  if options.has("connect"):
   # First-frame shader compilation must finish before starting the network deadline.
   if not headless:
    await RenderingServer.frame_post_draw
    if session.diagnostics:print(JSON.stringify({"event":"client_render_ready","wall_ms":Time.get_ticks_msec()}))
   session.connect_to(options.connect,int(options.get("port","24567")),{"plane":int(options.get("plane","0")),"profile":int(options.get("profile","0")),"mode":str(options.get("mode","free")),"code":str(options.get("code","")),"private":options.has("private")})
   if ui:ui.menu.hide();ui.touch.show()
func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
  control_focused=false
  if session:session.controls=AviaFlight.neutral()
 elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:control_focused=true
func _physics_process(_delta: float) -> void:
 if not session.joined:return
 if not bot and not control_focused:session.controls=AviaFlight.neutral();return
 if bot:
  var c: Dictionary=AviaFlight.neutral();c.throttle=0.8
  if not session.local_state.is_empty():
   var s: Dictionary=session.local_state
   c.pitch=clampf((0.15-float(s.pitch))*3.0,-1,1) if s.p.y<110 else clampf((-0.02-float(s.pitch))*3.0,-1,1)
   if s.p.y>100:c.roll=0.25
   c.respawn=s.crashed or Vector2(s.p.x,s.p.z).length()>4500
   c.fire=session.mode=="pvp"
   if options.has("systems-cycle"):
    c.gear=s.grounded or int(s.age)<150;c.flaps=int(s.age)<120
    c.afterburner=int(s.age)<210;c.throttle=1.0
    c.brake=int(s.age)>300 and int(s.age)<330
   if session.mode=="race" and options.has("route"):
    var next: int=int(session.local_race.get("next",0))
    if next<AviaRules.CHECKPOINTS.size():
     var difference: Vector3=AviaRules.CHECKPOINTS[next]-s.p
     var heading: float=atan2(-difference.x,-difference.z)
     var turn: float=wrapf(heading-float(s.yaw),-PI,PI)
     c.roll=clampf(-turn*2,-1,1) if s.p.y>10 else 0.0
     var desired_pitch: float=clampf(-0.26+difference.y*0.005-float(s.v.y)*0.016,-0.55,0.3)
     if s.p.y<15:desired_pitch=0.15
     c.pitch=clampf((desired_pitch-float(s.pitch))*3,-1,1)
     c.throttle=0.7
    else:c.respawn=true

  session.controls=c
  if ui:ui.touch.throttle=float(c.throttle)
 elif ui:
  session.controls=ui.touch.command()
  if ui.touch.assistance and not session.local_state.is_empty() and int(session.local_state.plane)<3 and not session.local_state.grounded and absf(float(session.controls.pitch))<0.01:
   session.controls.pitch=clampf((0.02-float(session.local_state.pitch))*0.9,-0.35,0.35)
func _process(delta: float) -> void:
 elapsed+=delta
 if world:
  if ui:world.orbit=lerp_angle(world.orbit,ui.touch.look_yaw,delta*6)
  world.update_session(session,delta)
 if options.has("capture") and not headless and elapsed>8 and not captured:
  captured=true
  _capture.call_deferred(str(options.capture))
 if duration>0 and elapsed>=duration and not quitting:
  quitting=true
  var errors: Array[float]=session.corrections.duplicate();errors.sort()
  var frames: Array[float]=[]
  if ui:frames=ui.frame_times.duplicate();frames.sort()
  var ping: float=session.peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) if session.joined else 0
  print(JSON.stringify({"correction_p95_m":errors[int(errors.size()*0.95)] if errors.size()>0 else 0,"frame_p50_ms":frames[int(frames.size()*0.5)] if frames.size()>0 else 0,"frame_p95_ms":frames[int(frames.size()*0.95)] if frames.size()>0 else 0,"enet_rtt_ms":ping,"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"commands_sent":session.commands_sent,"last_input_ack":session.seq-session.pending.size(),"pending_inputs":session.pending.size(),"connection_status":session.status,"event":"summary","server":session.server,"seconds":elapsed,"joined":session.joined,"snapshots":session.snapshots,"seen_peers":session.seen_peers,"correction_max_m":session.correction_max,"rejected":session.rejected,"state":session.local_state,"renderer":RenderingServer.get_current_rendering_method()}))
  if not session.server and session.joined:
   session.joined=false
   session.peer.get_peer(1).peer_disconnect()
   await get_tree().create_timer(0.3).timeout
  get_tree().quit()
func _capture(path: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image=get_viewport().get_texture().get_image()
 var result: Error=image.save_png(path)
 print(JSON.stringify({"event":"capture","path":path,"error":result}))
