class_name AviaRules
extends RefCounted
const CHECKPOINTS: Array[Vector3]=[Vector3(0,70,-430),Vector3(500,140,-900),Vector3(1000,110,-550),Vector3(500,100,100),Vector3(0,65,260)]
const RADIUS: float=65.0
static func race_tick(race: Dictionary, before: Vector3, after: Vector3, tick: int) -> String:
 var index: int=int(race.get("next",0))
 if index>=CHECKPOINTS.size(): return ""
 if AviaFlight.segment_distance(before,after,CHECKPOINTS[index])>RADIUS: return ""
 if index==0: race.start=tick
 race.next=index+1
 if int(race.next)==CHECKPOINTS.size():
  race.time=float(tick-int(race.start))*AviaFlight.DT
  return "finish"
 return "checkpoint"
static func shot_hit(shooter: Dictionary, victim: Dictionary) -> bool:
 var from: Vector3=shooter.p
 var to: Vector3=from-Basis.from_euler(Vector3(shooter.pitch,shooter.yaw,shooter.roll)).z*600.0
 if AviaFlight.segment_distance(from,to,victim.p)>7.0: return false
 var distance: float=from.distance_to(victim.p)
 for i: int in range(1,maxi(2,ceili(distance/5.0))):
  var p: Vector3=from.lerp(victim.p,float(i)/maxi(2,ceili(distance/5.0)))
  if p.y<=AviaFlight.height(p):return false
 return true
