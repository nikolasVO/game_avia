class_name AviaFighter
extends RefCounted
## Arcade forces in m/s². All parameters are authored game balance, not flight-manual data.
## No client delta/time, position, profile, thrust or mass is trusted by this module.
static func sweep_fraction(spec: Dictionary,speed_mps: float,gear: bool,flaps: bool) -> float:
 if not bool(spec.systems.get("variable_sweep",false)) or gear or flaps:return 0.0
 var schedule: Dictionary=spec.get("sweep",{})
 var start: float=float(schedule.get("start_speed_kmh",648.0))/3.6
 var finish: float=float(schedule.get("full_speed_kmh",1188.0))/3.6
 return clampf((speed_mps-start)/maxf(1.0,finish-start),0,1)
static func step(s: Dictionary,c: Dictionary) -> Dictionary:
 return step_spec(s,c,AviaFlight.PLANES[int(s.plane)])
static func step_spec(s: Dictionary,c: Dictionary,spec: Dictionary) -> Dictionary:
 var n: Dictionary=s.duplicate();n.landed=false;n.age+=1
 if n.crashed:return n
 var f: Dictionary=spec.flight;var h: Dictionary=spec.handling
 var dt: float=AviaFlight.DT
 var p: Vector3=n.p;var v: Vector3=n.v
 var profile: int=int(n.profile)
 var density: float=exp(-maxf(p.y,0.0)/8500.0)
 # Shared deterministic light wind; server age is carried in every snapshot.
 var wind: Vector3=Vector3(1.5+sin(float(n.age)*0.009)*0.7,0,sin(float(n.age)*0.013)*0.5)
 if n.grounded:wind=Vector3.ZERO # Tyre/static-friction approximation prevents parked wind drift.
 var air: Vector3=v-wind;var speed: float=air.length()
 # Weight-on-wheels interlock also protects a fresh spawn from in-flight queued inputs.
 n.gear=bool(c.gear) or bool(n.grounded);n.flaps=bool(c.flaps) and spec.systems.flaps
 n.afterburner=bool(c.afterburner) and spec.systems.afterburner and float(c.throttle)>0.8
 n.airbrake=bool(c.brake) and spec.systems.airbrake
 # Automatic game schedule is derived from approved velocity/systems on both peers.
 # It requires no new client command or protocol field. Current six fighters use 0.
 var sweep: float=sweep_fraction(spec,v.length(),n.gear,n.flaps)
 var sweep_config: Dictionary=spec.get("sweep",{})
 var stall: float=float(spec.stall)*(0.85 if n.flaps else 1.0)/sqrt(density)
 var control: float=lerpf(float(h.low_speed_control)/100.0,float(h.high_speed_control)/100.0,clampf(speed/220.0,0,1))
 control*=clampf(speed/stall,0.12,1.0)
 if spec.systems.thrust_vectoring:control+=clampf(1.0-speed/stall,0,1)*float(c.throttle)*0.65
 var pitch: float=float(c.pitch)
 if profile==0 and absf(pitch)<0.01:
  pitch=clampf((0.025-float(n.pitch))*0.8,-0.25,0.25)
 if profile==1 and absf(pitch)<0.01:pitch=clampf((0.025-float(n.pitch))*0.2,-0.08,0.08)
 if profile==0 and speed<stall and not n.grounded:pitch=minf(pitch,-0.12)
 var authority: float=(0.75+float(h.maneuverability)/100.0*0.55)*control
 authority*=lerpf(1.0,float(sweep_config.get("closed_control_ratio",1.0)),sweep)
 var rates: Vector3=n.rates
 var pitch_target: float=pitch*(0.5+float(h.pitch_response)*0.01)*authority
 var roll_target: float=-float(c.roll)*(0.9+float(h.roll_response)*0.022)*authority
 if profile==0:roll_target=clampf((-float(c.roll)*1.05-float(n.roll))*3.0,-3,3)*authority
 if profile==1 and absf(float(c.roll))<0.01:roll_target=-float(n.roll)*0.35
 var yaw_target: float=float(c.yaw)*(0.15+float(h.yaw_response)*0.003)*authority
 var bank_yaw: float=sin(float(n.roll))*9.81/maxf(speed,25.0)*(1.4 if profile==0 else 1.0) if not n.grounded else 0.0
 var response: float=1.0-exp(-dt/(0.12+float(h.inertia)*0.009))
 rates=rates.lerp(Vector3(pitch_target,yaw_target,roll_target),clampf(response,0,1))
 # Preserve fractional acceleration: quantizing each tick creates a low-input dead zone.
 # Only snapshots quantize angular rates (<=1/64 rad/s error per axis).
 for i: int in 3:rates[i]=clampf(rates[i],-3.96875,3.96875)
 n.rates=rates
 n.pitch=clampf(float(n.pitch)+rates.x*dt,-1.25,1.25)
 n.roll=wrapf(float(n.roll)+rates.z*dt,-PI,PI)
 n.yaw=wrapf(float(n.yaw)+(rates.y+bank_yaw)*dt,-PI,PI)
 if n.grounded:
  n.pitch=clampf(float(n.pitch),-0.02,0.24);n.roll=lerpf(float(n.roll),0,0.3)
  n.yaw+=(-float(c.roll)*0.3+float(c.yaw)*0.4)*dt*clampf(speed/10,0,1)
 var basis: Basis=Basis.from_euler(Vector3(n.pitch,n.yaw,n.roll))
 var forward: Vector3=-basis.z;var up: Vector3=basis.y
 var axial: float=maxf(0,air.dot(forward))
 var flow_pitch: float=atan2(air.y,Vector2(air.x,air.z).length())
 var aoa: float=wrapf(float(n.pitch)-flow_pitch,-PI,PI)
 var stalled: float=clampf(axial/stall,0,1)
 var lift: float=9.81*density*pow(axial/float(spec.stall),2)*(0.70+aoa*5.0+(0.25 if n.flaps else 0.0))
 lift*=stalled*stalled
 lift*=lerpf(1.0,float(sweep_config.get("closed_lift_ratio",1.0)),sweep)
 if absf(aoa)>0.45:lift*=maxf(0.15,1.0-(absf(aoa)-0.45)*1.7)
 lift=clampf(lift,-25,35 if profile==0 else 40 if profile==1 else 45)
 if n.grounded and axial<float(f.takeoff_speed_kmh)/3.6*(0.95+float(h.takeoff_difficulty)*0.001):lift=minf(lift,9.6)
 var thrust: float=float(f.afterburner_acceleration_mps2 if n.afterburner else f.acceleration_mps2)*float(c.throttle)*pow(density,0.35)
 var ceiling: float=lerpf(float(f.max_speed_sea_kmh),float(f.max_speed_altitude_kmh),clampf(p.y/10000.0,0,1))/3.6
 # Force-derived terminal speed: published ceiling is not an assigned velocity.
 var drag: float=float(f.afterburner_acceleration_mps2)/pow(float(f.max_speed_sea_kmh)/3.6,2)*density
 drag*=lerpf(1.0,float(sweep_config.get("closed_drag_ratio",1.0)),sweep)
 drag+=0.00012*absf(aoa)+rates.length()*0.00010*(1.0 if profile==0 else 1.3 if profile==1 else 1.6)
 if n.gear:drag+=0.00028
 if n.flaps:drag+=0.00040
 if n.airbrake:drag+=0.0018
 if speed>ceiling:drag+=0.003*pow((speed-ceiling)/maxf(ceiling,1),2)
 var accel: Vector3=forward*thrust+up*lift+Vector3.DOWN*9.81-air*speed*drag
 var side_slip: Vector3=air-forward*air.dot(forward)
 accel-=side_slip*(0.4+float(h.stability)*0.009)*(0.65 if profile==2 else 0.85 if profile==1 else 1.0)
 if n.grounded:accel-=Vector3(v.x,0,v.z)*(2.0 if c.brake else 0.10)
 v+=accel*dt
 v=v.limit_length(float(spec.max)*1.15)
 var target: Vector3=p+v*dt
 var crashed: bool=false
 var samples: int=maxi(1,ceili(p.distance_to(target)/3.0))
 for i: int in range(1,samples+1):
  var point: Vector3=p.lerp(target,float(i)/samples)
  if point.y<=AviaFlight.height(point)+AviaFlight.GROUND:
   var difficulty: float=float(h.landing_difficulty)/100.0
   var safe: bool=AviaFlight.runway(point) and n.gear and v.y>-(6.0-difficulty*2) and absf(float(n.roll))<0.35 and absf(float(n.pitch))<0.3 and speed<float(f.landing_speed_kmh)/3.6*1.25
   if not safe:crashed=true
   else:
    target.y=AviaFlight.GROUND;v.y=maxf(v.y,0)
    n.landed=not bool(n.grounded) and bool(n.was_airborne);n.grounded=true
    if c.brake:n.pitch=lerpf(float(n.pitch),0,0.2)
   break
 if target.y>AviaFlight.GROUND+1.5:n.grounded=false;n.was_airborne=true
 if Vector2(target.x,target.z).length()>5500.0 or target.y>2500.0 or target.y < -15.0:crashed=true
 n.p=target;n.v=v;n.distance+=p.distance_to(target)
 if crashed:n.crashed=true;n.health=0.0;n.v=Vector3.ZERO
 return n
