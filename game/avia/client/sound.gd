class_name AviaSound
extends AudioStreamPlayer
## Original game synthesis, not recordings or technical signatures of real aircraft.
## Five local players plus at most four nearby remote voices; no simulation changes.
var session: Node
var world: Node3D
static var tones: Dictionary={}
static var config: Dictionary={}
var active_plane: int=-1
var wind: AudioStreamPlayer
var burner: AudioStreamPlayer
var warning: AudioStreamPlayer
var cue: AudioStreamPlayer
var remote_voices: Dictionary={}
var previous: Dictionary={}
var cue_counts: Dictionary={}
var cue_times: Dictionary={}
var suspended: bool=false
var unfocused: bool=false
var baseline_only: bool=false
var clock: float=0.0
var remote_clock: float=0.0
var remote_elapsed: float=0.0
var remote_peak: int=0
var engine_changes: int=0
static func settings() -> Dictionary:
 if config.is_empty():config=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
 return config
static func engine_stream(index: int=0) -> AudioStreamWAV:
 var rows: Array[Dictionary]=AviaCatalog.playable()
 var id: String=rows[clampi(index,0,rows.size()-1)].aircraft_id
 return engine_stream_for_id(id)
static func engine_stream_for_id(id: String) -> AudioStreamWAV:
 # Inspection uses stable IDs without admitting planned models to flight.
 # An unknown ID has no sound instead of silently borrowing another aircraft.
 var profile: String=settings().aircraft.get(id,"")
 if not settings().profiles.has(profile):return null
 var key: String="engine:"+profile
 if tones.has(key):return tones[key]
 var spec: Dictionary=settings().profiles[profile]
 return _synthesize(key,1.0,true,spec)
static func effect_stream(kind: String) -> AudioStreamWAV:
 if tones.has(kind):return tones[kind]
 var duration: float=1.0 if kind in ["wind","burner","stall"] else 0.5 if kind in ["start","crash"] else 0.28
 return _synthesize(kind,duration,kind in ["wind","burner","stall"],{})
static func _synthesize(key: String,duration: float,loop: bool,spec: Dictionary) -> AudioStreamWAV:
 var rate: int=int(settings().mix_rate)
 var count: int=int(rate*duration)
 var data: PackedByteArray=PackedByteArray();data.resize(count*2)
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=abs(key.hash())
 var filtered: float=0.0
 for i: int in count:
  var t: float=float(i)/rate
  filtered=lerpf(filtered,rng.randf_range(-1.0,1.0),0.24)
  # Noise fades at the loop seam, integer-Hz periodic tones remain continuous.
  var seam: float=minf(1.0,float(mini(i,count-1-i))/96.0)
  var noise: float=filtered*seam
  var value: float=0.0
  if not spec.is_empty():
   var base: float=spec.base_hz
   var beat: float=spec.beat_hz
   value=0.13*sin(TAU*base*t)+0.05*sin(TAU*base*2.0*t)+0.035*sin(TAU*float(spec.whine_hz)*t)
   if beat>0:value+=0.065*sin(TAU*(base+beat)*t)
   value+=noise*float(spec.noise)*0.35
  else:
   match key:
    "wind":value=noise*0.55
    "burner":value=noise*0.7+0.06*sin(TAU*48*t)
    "stall":value=0.22*sin(TAU*880*t)*pow(maxf(0.0,sin(TAU*2*t)),2.0)
    "start":value=(0.12*sin(TAU*(55*t+140*t*t))+noise*0.16)*sin(PI*t/duration)
    "gear":value=(0.12*sin(TAU*180*t)+noise*0.45)*sin(PI*t/duration)
    "touchdown":value=(0.22*sin(TAU*45*t)+noise*0.55)*sin(PI*t/duration)
    "crash":value=(noise*0.9+0.18*sin(TAU*32*t))*sin(PI*t/duration)
  data.encode_s16(i*2,int(clampf(value,-0.8,0.8)*32767.0))
 var result: AudioStreamWAV=AudioStreamWAV.new()
 result.format=AudioStreamWAV.FORMAT_16_BITS;result.mix_rate=rate;result.data=data
 if loop:result.loop_mode=AudioStreamWAV.LOOP_FORWARD;result.loop_end=count
 tones[key]=result
 return result
func _player(kind: String) -> AudioStreamPlayer:
 var player: AudioStreamPlayer=AudioStreamPlayer.new();player.name=kind.capitalize();player.stream=effect_stream(kind);player.volume_db=-60;player.max_polyphony=1;add_child(player)
 return player
func _ready() -> void:
 volume_db=-60;max_polyphony=1
 wind=_player("wind");burner=_player("burner");warning=_player("stall");cue=_player("start")
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_PAUSED:suspended=true;baseline_only=true;_silence(false)
 elif what==NOTIFICATION_APPLICATION_RESUMED:suspended=false
 elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:unfocused=true;baseline_only=true;_silence(false)
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:unfocused=false
func _silence(reset: bool) -> void:
 stop();volume_db=-60
 for player: AudioStreamPlayer in [wind,burner,warning,cue]:
  if is_instance_valid(player):player.stop();player.volume_db=-60
 _clear_remote()
 if reset:previous.clear();active_plane=-1;baseline_only=false
func _clear_remote() -> void:
 for player: AudioStreamPlayer3D in remote_voices.values():
  if is_instance_valid(player):player.stop();player.queue_free()
 remote_voices.clear();remote_clock=0.0;remote_elapsed=0.0
func _exit_tree() -> void:
 _silence(true)
 if is_instance_valid(session) and session.get("diagnostics"):
  print(JSON.stringify({"event":"audio_summary","engine_changes":engine_changes,"remote_peak":remote_peak,"remote_limit":settings().remote_voice_limit,"cues":cue_counts,"scope":"original synthesized audio; phone acoustics not verified"}))
func _layer(player: AudioStreamPlayer,target: float,delta: float,pitch: float=1.0) -> void:
 player.volume_db=lerpf(player.volume_db,target,1.0-exp(-delta*7.0))
 player.pitch_scale=lerpf(player.pitch_scale,pitch,1.0-exp(-delta*5.0))
 if target>-59 and not player.playing:player.play()
 elif target<=-59 and player.volume_db<-58:player.stop()
func _cue(kind: String) -> void:
 # Predicted/reconciled landing and gear edges must not rattle repeatedly.
 if clock-float(cue_times.get(kind,-100.0))<1.5:return
 cue_times[kind]=clock;cue_counts[kind]=int(cue_counts.get(kind,0))+1
 cue.stop();cue.stream=effect_stream(kind);cue.volume_db=-16;cue.pitch_scale=1;cue.play()
func _events(state: Dictionary) -> void:
 if baseline_only:previous=state.duplicate();baseline_only=false;return
 if previous.is_empty() or int(previous.plane)!=int(state.plane) or int(previous.respawns)!=int(state.respawns):
  if not state.crashed:_cue("start")
 elif int(state.age)>=int(previous.age):
  if state.crashed and not previous.crashed:_cue("crash")
  elif not state.crashed:
   if bool(state.gear)!=bool(previous.gear):_cue("gear")
   if bool(state.grounded) and not bool(previous.grounded) and bool(state.was_airborne):_cue("touchdown")
 previous=state.duplicate()
func _process(delta: float) -> void:
 clock+=delta
 if suspended or unfocused:return
 if not is_instance_valid(session) or not session.joined or session.local_state.is_empty():_silence(true);return
 var state: Dictionary=session.local_state
 _events(state)
 if state.crashed:
  stop();volume_db=-60
  for player: AudioStreamPlayer in [wind,burner,warning]:player.stop();player.volume_db=-60
  _clear_remote();return
 var index: int=int(state.plane)
 if active_plane!=index:
  active_plane=index;stream=engine_stream(index);volume_db=-60;engine_changes+=1
 var speed: float=state.v.length()
 var throttle: float=clampf(float(session.controls.throttle),0,1)
 var inside: bool=is_instance_valid(world) and world.get("cockpit")==true
 var engine_db: float=-22.0+throttle*10.0-(5.0 if inside else 0.0)
 _layer(self,engine_db,delta,0.65+throttle*0.95+minf(speed/400.0,0.35))
 _layer(wind,-60.0 if speed<8 else clampf(-42.0+speed*0.12,-42,-18)-(10.0 if inside else 0.0),delta,0.8+minf(speed/500.0,0.7))
 _layer(burner,(-20.0-(7.0 if inside else 0.0)) if bool(state.afterburner) else -60.0,delta)
 var spec: Dictionary=AviaFlight.PLANES[index]
 var density: float=exp(-maxf(float(state.p.y),0.0)/8500.0)
 var stall: float=float(spec.stall)/sqrt(density)*(0.85 if bool(state.flaps) else 1.0)
 var stalled: bool=not state.grounded and speed<stall*1.1
 _layer(warning,-18.0 if stalled else -60.0,delta)
 _remote(delta,state,inside)
func _remote(delta: float,local: Dictionary,inside: bool) -> void:
 if not is_instance_valid(world):_clear_remote();return
 remote_clock-=delta;remote_elapsed+=delta
 if remote_clock>0:return
 var elapsed: float=remote_elapsed;remote_elapsed=0.0;remote_clock=0.1
 var nearby: Array[Dictionary]=[]
 for id: int in session.others:
  var state: Dictionary=session.remote_state(id)
  if state.is_empty() or state.crashed:continue
  var distance: float=local.p.distance_to(state.p)
  if distance<float(settings().remote_range_m):nearby.append({"id":id,"distance":distance,"state":state})
 nearby.sort_custom(func(a: Dictionary,b: Dictionary):return a.distance<b.distance if a.distance!=b.distance else a.id<b.id)
 nearby.resize(mini(nearby.size(),clampi(int(settings().remote_voice_limit),0,4)))
 var wanted: Array[int]=[]
 for entry: Dictionary in nearby:wanted.append(entry.id)
 for id: int in remote_voices.keys():
  if not id in wanted:remote_voices[id].stop();remote_voices[id].queue_free();remote_voices.erase(id)
 for entry: Dictionary in nearby:
  var id: int=entry.id
  var state: Dictionary=entry.state
  var player: AudioStreamPlayer3D=remote_voices.get(id)
  if not player:
   player=AudioStreamPlayer3D.new();player.name="RemoteEngine"+str(id);player.unit_size=24;player.max_distance=float(settings().remote_range_m);player.max_polyphony=1;player.volume_db=-60;world.add_child(player);remote_voices[id]=player
  var tone: AudioStreamWAV=engine_stream(int(state.plane))
  if player.stream!=tone:player.stream=tone
  player.position=state.p;player.volume_db=lerpf(player.volume_db,-24.0-(7.0 if inside else 0.0),1.0-exp(-elapsed*7.0))
  player.pitch_scale=lerpf(player.pitch_scale,0.8+minf(state.v.length()/200.0,1.2),1.0-exp(-elapsed*5.0))
  if not player.playing:player.play()
 remote_peak=maxi(remote_peak,remote_voices.size())
