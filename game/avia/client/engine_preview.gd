class_name AviaEnginePreview
extends AudioStreamPlayer
## One bounded original game sound sample; never changes flight admission.
signal sample_changed
var sample_id: String=""
var remaining: float=0.0
func _ready() -> void:
 max_polyphony=1;volume_db=-22;set_process(false)
func start_sample(id: String) -> bool:
 stop_sample()
 if AudioServer.is_bus_mute(0):return false
 var tone: AudioStreamWAV=AviaSound.engine_stream_for_id(id)
 if tone==null:return false
 sample_id=id;stream=tone;pitch_scale=1.0
 remaining=clampf(float(AviaSound.settings().get("preview_seconds",4.0)),0.5,5.0)
 play();set_process(true);sample_changed.emit();return true
func stop_sample() -> void:
 var active: bool=not sample_id.is_empty()
 stop();stream=null;sample_id="";remaining=0;set_process(false)
 if active:sample_changed.emit()
func _process(delta: float) -> void:
 remaining=maxf(0.0,remaining-maxf(0.0,delta))
 if remaining<=0 or AudioServer.is_bus_mute(0):stop_sample()
func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:stop_sample()
func _exit_tree() -> void:stop_sample()
