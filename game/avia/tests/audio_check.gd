extends SceneTree
## Real Godot players/mixer, with a deterministic session fixture for lifecycle edges.
## This does not establish physical-device audio quality or network acceptance.
class AudioSession extends Node:
 var joined: bool=true
 var diagnostics: bool=false
 var controls: Dictionary=AviaFlight.neutral()
 var local_state: Dictionary=AviaFlight.spawn(3)
 var others: Dictionary={}
 func remote_state(id: int) -> Dictionary:return others[id]
class AudioWorld extends Node3D:
 var cockpit: bool=false
var checks: Array[Dictionary]=[]
var metrics: Array[Dictionary]=[]
var recorder: AudioEffectRecord
var sound: AviaSound
var session: AudioSession
var world: AudioWorld
func check(ok: bool,label: String) -> void:checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func capture(label: String,seconds: float=0.22) -> Dictionary:
 await create_timer(0.3).timeout # allow device startup and drain the previous mix block before a measurement
 recorder.set_recording_active(true)
 await create_timer(seconds).timeout
 recorder.set_recording_active(false)
 var wav: AudioStreamWAV=recorder.get_recording()
 if wav==null:push_error("No digital mix captured; audio driver must actually mix");quit(2);return {}
 var data: PackedByteArray=wav.data
 var square: float=0.0;var peak: float=0.0
 for i: int in range(0,data.size(),2):
  var sample: float=float(data.decode_s16(i))/32768.0
  square+=sample*sample;peak=maxf(peak,absf(sample))
 var row: Dictionary={"label":label,"samples":data.size()/2,"peak":peak,"rms":sqrt(square/maxi(1,data.size()/2))}
 var directory: String=OS.get_environment("AVIA_AUDIO_CHECK_DIR")
 if not directory.is_empty():wav.save_to_wav(directory.path_join(label+".wav"))
 metrics.append(row);return row
func _run() -> void:
 print(JSON.stringify({"event":"audio_driver","driver":AudioServer.get_driver_name()}))
 recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
 AudioServer.add_bus_effect(0,recorder)
 world=AudioWorld.new();root.add_child(world)
 var camera: Camera3D=Camera3D.new();world.add_child(camera);camera.current=true
 session=AudioSession.new();root.add_child(session)
 sound=AviaSound.new();sound.session=session;sound.world=world;root.add_child(sound);sound.set_process(false)
 # All playable craft must have an explicit, cached identity instead of fallback.
 var hashes: Array[int]=[];var configured: bool=true
 for i: int in AviaFlight.PLANES.size():
  var row: Dictionary=AviaFlight.PLANES[i]
  configured=configured and AviaSound.settings().aircraft.has(row.aircraft_id)
  var stream: AudioStreamWAV=AviaSound.engine_stream(i)
  check(stream==AviaSound.engine_stream(i) and stream.data.size()==44100 and stream.loop_end==22050,"engine cache and PCM loop "+row.aircraft_id)
  hashes.append(hash(stream.data))
 var unique: Dictionary={}
 for h: int in hashes:unique[h]=true
 check(configured and unique.size()==9,"nine configured original aircraft/jet identities have distinct PCM")
 var candidate_ids: Array[String]=["f14","fa18e","mig21","mig31","tornado"]
 for id: String in candidate_ids:
  var stream: AudioStreamWAV=AviaSound.engine_stream_for_id(id)
  var fingerprint: int=hash(stream.data) if stream else 0
  check(stream!=null and stream==AviaSound.engine_stream_for_id(id) and stream.data.size()==44100 and stream.loop_end==22050 and not unique.has(fingerprint) and AviaCatalog.index_of(id)==-1,"distinct cached candidate PCM without flight admission "+id)
  unique[fingerprint]=true
 check(unique.size()==14 and AviaSound.engine_stream_for_id("unknown")==null,"fourteen explicit identities and no unknown-ID fallback")
 sound._process(1.0);sound.cue.stop()
 var idle: Dictionary=await capture("idle")
 session.controls.throttle=1.0;sound._process(1.0)
 var powered: Dictionary=await capture("powered")
 check(idle.rms>0.0001 and powered.rms>idle.rms*2.0 and sound.pitch_scale>1.5,"actual mixed engine ramps amplitude and pitch with throttle")
 # Fifteen remote peers may occupy the room, but only four nearest alive voices mix.
 for id: int in range(2,17):
  var state: Dictionary=AviaFlight.spawn((id-2)%9)
  state.p=session.local_state.p+Vector3(id*8,0,-10);state.v=Vector3(0,0,-100);session.others[id]=state
 session.others[2].crashed=true;session.others[3].p=Vector3(9000,0,0)
 sound._process(0.2)
 check(sound.remote_voices.size()==4 and sound.remote_voices.has(4) and sound.remote_voices.has(7) and not sound.remote_voices.has(2) and not sound.remote_voices.has(3),"only four nearest live in-range peers get real 3D players")
 check(sound.remote_voices[4].stream==AviaSound.engine_stream(2),"remote voice reuses cached aircraft stream")
 session.others.erase(4);session.others[5].crashed=true;sound._process(0.2);await process_frame
 check(not sound.remote_voices.has(4) and not sound.remote_voices.has(5) and sound.remote_voices.size()==4,"departure and crash evict voices and admit next peers")
 session.local_state.grounded=false;session.local_state.was_airborne=true;session.local_state.p.y=100
 session.local_state.v=Vector3(0,0,-220);session.local_state.afterburner=true;sound._process(1.0)
 var external: Dictionary=await capture("high_speed_afterburner")
 check(sound.wind.playing and sound.burner.playing and not sound.warning.playing,"speed and replicated afterburner drive independent layers")
 world.cockpit=true;sound._process(1.0)
 var internal: Dictionary=await capture("cockpit")
 check(internal.rms<external.rms*0.8,"cockpit camera attenuates real mixed external engine/wind")
 world.cockpit=false;session.local_state.afterburner=false;session.local_state.v=Vector3(0,0,-12);sound._process(1.0)
 check(sound.warning.playing and not sound.burner.playing,"airborne low speed warns and afterburner fades to stop")
 var stalled: Dictionary=await capture("stall_warning",0.55)
 check(stalled.rms>0.001,"stall warning is present in the actual mixer")
 # Event edges: repeated snapshots, correction and respawn must not replay impacts.
 session.local_state.age=10;session.local_state.gear=false;sound._process(2.0)
 for i: int in 10:sound._process(0.01)
 check(sound.cue_counts.get("gear",0)==1,"gear cue once across repeated snapshots")
 session.local_state.age=11;session.local_state.grounded=true;sound._process(2.0)
 for i: int in 10:sound._process(0.01)
 session.local_state.age=9;session.local_state.grounded=false;sound._process(0.1)
 session.local_state.age=11;session.local_state.grounded=true;sound._process(0.1)
 check(sound.cue_counts.get("touchdown",0)==1,"touchdown cue once across repeated state and short reconciliation")
 session.local_state.age=12;session.local_state.crashed=true;sound._process(2.0)
 for i: int in 10:sound._process(0.01)
 check(sound.cue_counts.get("crash",0)==1 and not sound.playing and sound.remote_voices.is_empty(),"one crash cue, engine/remote loops stop")
 session.local_state=AviaFlight.spawn(3);session.local_state.respawns=1;sound._process(2.0)
 check(sound.cue_counts.get("touchdown",0)==1 and sound.cue_counts.get("start",0)==2,"respawn starts engine without false landing/gear impact")
 sound._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(not sound.playing and not sound.cue.playing and sound.remote_voices.is_empty(),"pause immediately stops every player including cues/remotes")
 var silence: Dictionary=await capture("paused_silence")
 check(silence.samples>1000 and silence.peak==0,"actual mixer is silent after pause")
 var count: int=int(sound.cue_counts.get("start",0))
 sound._notification(Node.NOTIFICATION_APPLICATION_RESUMED);sound._process(1.0)
 check(sound.playing and int(sound.cue_counts.get("start",0))==count,"resume restarts loops without replaying startup event")
 sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not sound.playing and sound.remote_voices.is_empty(),"focus loss stops audio independently of pause")
 sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);sound._process(1.0)
 session.joined=false;sound._process(0.02)
 var menu: Dictionary=await capture("menu_silence")
 check(menu.peak==0 and sound.remote_voices.is_empty(),"disconnect/menu leaves no stale mixed voices")
 # Real AudioServer mute switch is already wired to the UI Sound option.
 session.joined=true;sound._process(2.0);sound.cue.stop();AudioServer.set_bus_mute(0,true)
 check(AudioServer.is_bus_mute(0),"master mute remains supported")
 AudioServer.set_bus_mute(0,false)
 var bounded: bool=metrics.all(func(row: Dictionary):return row.samples>1000 and row.peak<0.95)
 check(bounded,"captured digital mix has frames and no clipping in exercised states")
 var voices: Array= sound.remote_voices.values()
 sound.queue_free();await process_frame;await process_frame
 check(voices.all(func(player: Variant):return not is_instance_valid(player)),"manager deletion also frees world-owned 3D players")
 # Planned models are audible through one bounded inspection player only.
 var preview: AviaEnginePreview=AviaEnginePreview.new();root.add_child(preview)
 for id: String in candidate_ids:
  check(preview.start_sample(id) and preview.sample_id==id and preview.max_polyphony==1 and preview.remaining<=5.0,"bounded actual sample starts "+id)
  var sample: Dictionary=await capture("candidate_"+id)
  check(sample.rms>0.0005 and sample.peak<0.5,"candidate original sound reaches actual digital mixer "+id)
 preview.stop_sample()
 var stopped: Dictionary=await capture("preview_stopped")
 check(stopped.peak==0 and preview.stream==null and preview.sample_id.is_empty(),"stopping preview clears stream and digital mix")
 check(not preview.start_sample("unknown") and not preview.playing,"unknown preview cannot play a borrowed engine")
 preview.start_sample("tornado");preview.set_process(false);preview._process(-1.0)
 check(is_equal_approx(preview.remaining,4.0),"negative elapsed time cannot extend sample")
 preview._process(5.01)
 check(not preview.playing and preview.remaining==0,"sample expires at bounded deadline")
 preview.start_sample("f14");preview._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(not preview.playing and preview.stream==null,"pause stops preview without automatic restart")
 preview.start_sample("mig31");preview._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not preview.playing,"focus loss stops inspection sound")
 preview.start_sample("mig21");AudioServer.set_bus_mute(0,true);preview._process(.01)
 check(not preview.playing and not preview.start_sample("f14"),"muting stops active sample and prevents a new one")
 AudioServer.set_bus_mute(0,false);preview.queue_free();await process_frame
 check(metrics.all(func(row: Dictionary):return row.samples>1000 and row.peak<0.95),"all candidate and flight digital captures remain bounded")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"audio_check_summary","status":"PASS" if ok else "FAIL","checks":checks,"metrics":metrics,"driver":AudioServer.get_driver_name(),"engine_hashes":hashes,"scope":"actual Godot players and recorded digital mixer; deterministic lifecycle fixture; not physical acoustics or aircraft acceptance"}))
 AudioServer.remove_bus_effect(0,0);world.queue_free();session.queue_free();await process_frame;quit(0 if ok else 1)
