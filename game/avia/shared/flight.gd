class_name AviaFlight
extends RefCounted
## Metres, seconds, radians; +Y up; aircraft nose -Z. Fixed 30 Hz on both peers.
const DT: float = 1.0 / 30.0
const GROUND: float = 1.4
const PLANES: Array[Dictionary] = [
 {"name":"Kite", "thrust":15.0,"drag":0.004,"lift":0.021,"turn":1.0,"stall":17.0,"max":72.0,"color":Color("e2b46e")},
 {"name":"Tern", "thrust":23.0,"drag":0.0035,"lift":0.016,"turn":1.35,"stall":23.0,"max":95.0,"color":Color("6dc4bc")},
 {"name":"Swift", "thrust":38.0,"drag":0.0027,"lift":0.009,"turn":0.8,"stall":32.0,"max":145.0,"color":Color("c4cfdf")}
]
static func neutral() -> Dictionary:
 return {"pitch":0.0,"roll":0.0,"yaw":0.0,"throttle":0.0,"brake":false,"fire":false,"respawn":false}
static func spawn(index: int = 0, slot: int = 0) -> Dictionary:
 return {"p":Vector3((slot % 4 - 1.5)*12.0,GROUND,180.0 + (slot / 4)*18.0),"v":Vector3.ZERO,
 "pitch":0.0,"yaw":0.0,"roll":0.0,"plane":clampi(index,0,2),"health":100.0,"crashed":false,
 "grounded":true,"was_airborne":false,"landed":false,"age":0,"distance":0.0,"respawns":0}
static func runway(p: Vector3) -> bool:
 return (absf(p.x)<32.0 and absf(p.z)<330.0) or (absf(p.x-900)<28 and absf(p.z+1000)<160)
static func height(p: Vector3) -> float:
 # Server and client share the exact procedural collision surface.
 if runway(p): return 0.0
 var h: float = -5.0
 for mountain: Vector4 in [Vector4(-520, -700, 210, 300),Vector4(650,-650,140,260),Vector4(-800,500,90,240)]:
  var d: float = Vector2(p.x-mountain.x,p.z-mountain.y).length()
  h = maxf(h, mountain.z * maxf(0.0,1.0-d/mountain.w)-5.0)
 if Vector2(p.x,p.z).length()<1450.0: h=maxf(h,-1.0)
 return h
static func valid_input(c: Dictionary) -> bool:
 if c.size()!=7: return false
 for k: String in ["pitch","roll","yaw","throttle"]:
  if not c.has(k) or not (c[k] is float or c[k] is int): return false
  var x: float = float(c[k])
  if not is_finite(x) or x < (-1.0 if k!="throttle" else 0.0) or x>1.0: return false
 for k: String in ["brake","fire","respawn"]:
  if not c.has(k) or not c[k] is bool: return false
 return true
static func segment_distance(a: Vector3,b: Vector3,p: Vector3) -> float:
 var ab: Vector3 = b-a
 return p.distance_to(a+ab*clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0))
static func step(s: Dictionary, c: Dictionary) -> Dictionary:
 var n: Dictionary=s.duplicate()
 n.landed=false
 n.age+=1
 if n.crashed: return n
 var spec: Dictionary=PLANES[n.plane]
 var p: Vector3=n.p
 var v: Vector3=n.v
 var speed: float=v.length()
 var authority: float=clampf(speed/24.0,0.18,1.0)*float(spec.turn)
 n.roll=lerpf(float(n.roll),-float(c.roll)*0.95,0.1*authority+0.04)
 n.pitch=clampf(float(n.pitch)+float(c.pitch)*authority*0.62*DT,-0.75,0.8)
 if bool(n.grounded):
  n.pitch=clampf(float(n.pitch),-0.02,0.25)
  n.yaw+=(-float(c.roll)*0.35+float(c.yaw)*0.4)*DT*clampf(speed/8.0,0.0,1.0)
 else:
  n.yaw+=(sin(float(n.roll))*0.7+float(c.yaw)*0.28)*DT*authority
 var basis: Basis=Basis.from_euler(Vector3(n.pitch,n.yaw,n.roll))
 var forward: Vector3=-basis.z
 var up: Vector3=basis.y
 var airspeed: float=maxf(0.0,v.dot(forward))
 var lift: float=minf(airspeed*airspeed*float(spec.lift),24.0)
 # Lift falls gradually below stall. No hidden altitude hold.
 lift*=clampf(airspeed/float(spec.stall),0.0,1.0)
 var accel: Vector3=forward*float(c.throttle)*float(spec.thrust)+up*lift+Vector3.DOWN*9.81
 accel-=v*speed*float(spec.drag)
 # Lateral damping keeps the arcade model controllable without teleporting velocity.
 accel-=(v-forward*v.dot(forward))*1.1
 if bool(n.grounded):
  accel-=Vector3(v.x,0,v.z)*(3.0 if c.brake else 0.13)
 v+=accel*DT
 v=v.limit_length(float(spec.max))
 var target: Vector3=p+v*DT
 var crashed: bool=false
 # Swept terrain test at <= 3 m intervals prevents high-speed tunnelling.
 var samples: int=maxi(1,ceili(p.distance_to(target)/3.0))
 for i: int in range(1,samples+1):
  var point: Vector3=p.lerp(target,float(i)/samples)
  if point.y<=height(point)+GROUND:
   var safe: bool=runway(point) and v.y > -5.0 and absf(float(n.roll))<0.4 and absf(float(n.pitch))<0.3 and speed<55.0
   if not safe: crashed=true
   else:
    target.y=GROUND
    v.y=maxf(v.y,0.0)
    n.landed=not bool(n.grounded) and bool(n.was_airborne)
    n.grounded=true
    if c.brake: n.pitch=lerpf(float(n.pitch),0.0,0.2)
   break
 if target.y>GROUND+1.5:
  n.grounded=false
  n.was_airborne=true
 if Vector2(target.x,target.z).length()>5500.0 or target.y>2500.0 or target.y < -15.0: crashed=true
 n.p=target
 n.v=v
 n.distance+=p.distance_to(target)
 if crashed:
  n.crashed=true
  n.health=0.0
  n.v=Vector3.ZERO
 return n
