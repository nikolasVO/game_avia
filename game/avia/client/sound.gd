class_name AviaSound
extends AudioStreamPlayer
## Original periodic engine tone; no downloaded audio or runtime model inference.
var session: Node
static var tones: Dictionary={}
var active_plane: int=-1
static func engine_stream(index: int=0) -> AudioStreamWAV:
 if tones.has(index):return tones[index]
 var stream_data: AudioStreamWAV=AudioStreamWAV.new();stream_data.format=AudioStreamWAV.FORMAT_16_BITS;stream_data.mix_rate=22050
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=83+index
 var base: float=80.0 if index<3 else 110.0+index*7.0
 var data: PackedByteArray=PackedByteArray();data.resize(22050*2)
 for i: int in range(22050):
  var t: float=float(i)/22050
  var value: int=int((sin(TAU*base*t)*0.5+sin(TAU*base*2*t)*0.22+sin(TAU*base*3*t)*0.1+rng.randf_range(-0.23,0.23)*(1.0 if index>=3 else .15))*3200)
  data.encode_s16(i*2,value)
 stream_data.data=data;stream_data.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream_data.loop_end=22050;tones[index]=stream_data
 return stream_data
func _ready() -> void:
 stream=engine_stream();volume_db=-24;play()
func _process(_delta: float) -> void:
 if session and session.joined and not session.local_state.is_empty() and not session.local_state.crashed:
  if active_plane!=int(session.local_state.plane):active_plane=int(session.local_state.plane);stream=engine_stream(active_plane);play()
  volume_db=lerpf(volume_db,-27+float(session.controls.throttle)*10,0.05)
  pitch_scale=lerpf(pitch_scale,0.6+float(session.controls.throttle)*1.3+minf(session.local_state.v.length()/200.0,0.6)+(0.15 if session.local_state.get("afterburner",false) else 0.0),0.1)
 else:volume_db=-60
