extends RefCounted
## Explicit development bot. Commands only; never score/position injection.
var stage: int=0
var bias: float=0
const PATH: Array[Vector3]=[Vector3(0,200,-1700),Vector3(2200,240,-2200),Vector3(2800,240,1600),Vector3(0,150,3000),Vector3(0,115,2200)]
func command(s: Dictionary) -> Dictionary:
 return command_spec(s,AviaFlight.PLANES[int(s.plane)])
func command_spec(s: Dictionary,spec: Dictionary) -> Dictionary:
 var c: Dictionary=AviaFlight.neutral()
 var target: Vector3=PATH[mini(stage,PATH.size()-1)]
 if stage>=4:target=Vector3(0,AviaFlight.GROUND+maxf(0,s.p.z-120)*.04,s.p.z-700)
 var difference: Vector3=target-s.p
 var distance: float=Vector2(difference.x,difference.z).length()
 var desired_heading: float=atan2(-difference.x,-difference.z)
 var heading_error: float=wrapf(desired_heading-float(s.yaw),-PI,PI)
 var approach: bool=stage>=4
 var speed_target: float=float(spec.stall)*1.20 if approach else 100.0
 c.gear=approach or not s.was_airborne;c.flaps=approach
 c.throttle=clampf(.14+(speed_target-s.v.length())*.025,0,1)
 c.roll=clampf(-heading_error*2,-1,1) if not s.grounded else 0.0
 var desired_vy: float=clampf((target.y-s.p.y)*.10-(Vector2(s.v.x,s.v.z).length()*.04 if approach else 0.0),-5.0,12.0)
 if approach and s.p.y<4:desired_vy=-1.0
 bias=clampf(bias+(desired_vy-s.v.y)*AviaFlight.DT*.0006,-.15,.15)
 var pitch_target: float=clampf(-.06+bias+(desired_vy-s.v.y)*.025+.06*(1-cos(float(s.roll))),-.3,.3)
 if not s.was_airborne:
  c.throttle=1;c.pitch=clampf((.15-float(s.pitch))*3,-1,1)
 else:c.pitch=clampf((pitch_target-float(s.pitch))*3-float(s.rates.x)*.5,-1,1)
 if s.grounded and s.was_airborne:c.throttle=0;c.brake=true
 if stage<PATH.size() and distance<280 and s.p.y>80:stage+=1
 return c
