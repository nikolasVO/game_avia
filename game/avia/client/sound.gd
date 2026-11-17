class_name AviaSound
extends AudioStreamPlayer
## Original periodic engine tone; no downloaded audio or runtime model inference.
var session: Node
static var tone: AudioStreamWAV
static func engine_stream() -> AudioStreamWAV:
 if tone:return tone
 var stream_data: AudioStreamWAV=AudioStreamWAV.new();stream_data.format=AudioStreamWAV.FORMAT_16_BITS;stream_data.mix_rate=22050
 var data: PackedByteArray=PackedByteArray();data.resize(22050*2)
 for i: int in range(22050):
  var t: float=float(i)/22050
  var value: int=int((sin(TAU*80*t)*0.6+sin(TAU*160*t)*0.22+sin(TAU*240*t)*0.1)*3200)
  data.encode_s16(i*2,value)
 stream_data.data=data;stream_data.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream_data.loop_end=22050;tone=stream_data
 return tone
func _ready() -> void:
 stream=engine_stream();volume_db=-24;play()
func _process(_delta: float) -> void:
 if session and session.joined and not session.local_state.is_empty() and not session.local_state.crashed:
  volume_db=lerpf(volume_db,-27+float(session.controls.throttle)*10,0.05)
  pitch_scale=0.6+float(session.controls.throttle)*1.3+minf(session.local_state.v.length()/200.0,0.6)
 else:volume_db=-60
