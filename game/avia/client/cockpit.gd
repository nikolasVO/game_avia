extends Node3D
## Authored generic lightweight cabin; no claim of a type-accurate cockpit.
var instruments: Control
var display: SubViewport
var elapsed: float=0.0
var meshes: Array[MeshInstance3D]=[]
func _ready() -> void:
 var frame: StandardMaterial3D=StandardMaterial3D.new()
 frame.albedo_color=Color("263b40");frame.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 for part: Array in [
  [Vector3(0,-.61,-1.25),Vector3(2.18,.44,.18)],
  [Vector3(-1.09,-.02,-1.24),Vector3(.07,1.45,.08)],
  [Vector3(1.09,-.02,-1.24),Vector3(.07,1.45,.08)],
  [Vector3(0,.71,-1.24),Vector3(2.22,.055,.08)]]:
  var mesh: BoxMesh=BoxMesh.new();mesh.size=part[1]
  var node: MeshInstance3D=MeshInstance3D.new();node.mesh=mesh;node.position=part[0];node.material_override=frame;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);meshes.append(node)
 display=SubViewport.new();display.size=Vector2i(640,160);display.disable_3d=true;display.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(display)
 instruments=load("res://client/cockpit_panel.gd").new();instruments.size=Vector2(640,160);display.add_child(instruments)
 var face: MeshInstance3D=MeshInstance3D.new();var panel: QuadMesh=QuadMesh.new();panel.size=Vector2(2.05,.5125)
 face.mesh=panel;face.position=Vector3(0,-.55,-1.145);face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var lit: StandardMaterial3D=StandardMaterial3D.new();lit.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;lit.albedo_texture=display.get_texture();face.material_override=lit;add_child(face);meshes.append(face)
 hide()
func update_instruments(state: Dictionary,delta: float,speed_unit: int,altitude_unit: int,language: String,throttle: float) -> void:
 if not visible:return
 elapsed+=delta
 if elapsed<.1 and not instruments.state.is_empty():return
 elapsed=0
 instruments.state=state.duplicate();instruments.state.throttle=throttle;instruments.speed_unit=speed_unit;instruments.altitude_unit=altitude_unit;instruments.language=language;instruments.queue_redraw()
 display.render_target_update_mode=SubViewport.UPDATE_ONCE
func deactivate() -> void:
 hide();elapsed=0
 if display:display.render_target_update_mode=SubViewport.UPDATE_DISABLED
