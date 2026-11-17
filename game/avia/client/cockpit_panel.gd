extends Control
## One small unlit instrument texture, refreshed only while the cockpit is visible.
var state: Dictionary={}
var speed_unit: int=0
var altitude_unit: int=0
var language: String="en"
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("142831"))
 if state.is_empty():return
 var font: Font=ThemeDB.fallback_font
 var ink: Color=Color("dfedcf");var muted: Color=Color("7bada7")
 var speed: float=state.v.length()*(3.6 if speed_unit==0 else 1.943844)
 var height: float=float(state.p.y)*(1.0 if altitude_unit==0 else 3.28084)
 var heading: int=int(fposmod(rad_to_deg(-float(state.yaw)),360))
 var captions: Array[String]=["SPD " if language=="en" else "СКОР ","ALT " if language=="en" else "ВЫС ","HDG" if language=="en" else "КУРС"]
 captions[0]+="km/h" if speed_unit==0 else "kt"
 captions[1]+="m" if altitude_unit==0 else "ft"
 for i: int in 3:
  var x: float=24+i*210
  draw_string(font,Vector2(x,28),captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,muted)
  draw_string(font,Vector2(x,75),"%03d" % [speed if i==0 else height if i==1 else heading],HORIZONTAL_ALIGNMENT_LEFT,-1,40,ink)
 var throttle: float=clampf(float(state.get("throttle",0)),0,1)
 draw_rect(Rect2(24,96,152,10),Color("314951"));draw_rect(Rect2(24,96,152*throttle,10),Color("dfbd79"))
 draw_string(font,Vector2(24,133),("THR %d%%" if language=="en" else "ТЯГА %d%%") % (throttle*100),HORIZONTAL_ALIGNMENT_LEFT,-1,18,muted)
 # Attitude indicator shows aircraft roll and pitch without rotating text.
 var center: Vector2=Vector2(294,111)
 var tilt: Vector2=Vector2(54,0).rotated(-float(state.roll))
 var pitch: Vector2=Vector2(0,clampf(float(state.pitch)*28,-20,20))
 draw_line(center-tilt+pitch,center+tilt+pitch,ink,3,true)
 draw_line(center-Vector2(8,0),center+Vector2(8,0),Color("dfbd79"),3,true)
 var systems: String=("GEAR" if language=="en" else "ШАССИ") if bool(state.get("gear",false)) else ""
 if bool(state.get("flaps",false)):systems+="  FLP"
 if bool(state.get("afterburner",false)):systems+="  AB"
 draw_string(font,Vector2(444,112),systems,HORIZONTAL_ALIGNMENT_LEFT,-1,18,muted)
 if not bool(state.get("grounded",false)) and state.v.length()<float(AviaFlight.PLANES[int(state.plane)].stall):
  draw_string(font,Vector2(444,140),"STALL" if language=="en" else "СВАЛИВАНИЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffbc83"))
