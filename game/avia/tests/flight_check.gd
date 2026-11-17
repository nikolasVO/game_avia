extends SceneTree
var failed: int=0
var checks: int=0
func check(value: bool,label: String) -> void:
 checks+=1
 print(JSON.stringify({"check":label,"status":"PASS" if value else "FAIL"}))
 if not value:failed+=1
func _initialize() -> void:
 var c: Dictionary=AviaFlight.neutral()
 check(AviaFlight.valid_input(c),"neutral input accepted")
 c.pitch=NAN;check(not AviaFlight.valid_input(c),"NaN rejected")
 c.pitch=INF;check(not AviaFlight.valid_input(c),"Inf rejected")
 c.pitch=2.0;check(not AviaFlight.valid_input(c),"out of range rejected")
 c=AviaFlight.neutral();c.position=Vector3(500,500,500);check(not AviaFlight.valid_input(c),"coordinate injection rejected")
 var all_takeoff: bool=true
 for plane: int in range(3):
  var s: Dictionary=AviaFlight.spawn(plane);c=AviaFlight.neutral();c.throttle=1.0
  for i: int in range(300):
   c.pitch=clampf((0.15-float(s.pitch))*3,-1,1)
   s=AviaFlight.step(s,c)
  all_takeoff=all_takeoff and s.was_airborne and not s.crashed and s.p.y>10
  print(JSON.stringify({"plane":plane,"altitude":s.p.y,"speed_mps":s.v.length(),"crashed":s.crashed}))
 check(all_takeoff,"all three aircraft accelerate and take off")
 var landing: Dictionary=AviaFlight.spawn();landing.p=Vector3(0,1.41,0);landing.v=Vector3(0,-2,-20);landing.grounded=false;landing.was_airborne=true
 var landed: Dictionary=AviaFlight.step(landing,AviaFlight.neutral())
 check(landed.landed and landed.grounded and not landed.crashed,"gentle runway landing")
 landing.v=Vector3(0,-30,-30)
 check(AviaFlight.step(landing,AviaFlight.neutral()).crashed,"hard impact crashes")
 landing.p=Vector3(400,2,0);landing.v=Vector3(0,-500,-80)
 check(AviaFlight.step(landing,AviaFlight.neutral()).crashed,"high speed ground impact swept")
 landing.p=Vector3(5500,50,0);landing.v=Vector3(100,0,0)
 check(AviaFlight.step(landing,AviaFlight.neutral()).crashed,"world boundary enforced")
 var race: Dictionary={"next":0}
 var out_of_order: String=AviaRules.race_tick(race,AviaRules.CHECKPOINTS[2],AviaRules.CHECKPOINTS[2],30)
 check(out_of_order.is_empty() and race.next==0,"out of order checkpoint ignored")
 for i: int in range(AviaRules.CHECKPOINTS.size()):
  var point: Vector3=AviaRules.CHECKPOINTS[i]
  AviaRules.race_tick(race,point+Vector3(0,0,100),point-Vector3(0,0,100),30+i*30)
 check(race.next==5 and is_equal_approx(float(race.time),4.0),"ordered swept race finish uses server ticks")
 var shooter: Dictionary=AviaFlight.spawn();shooter.p=Vector3(0,100,0)
 var victim: Dictionary=AviaFlight.spawn();victim.p=Vector3(0,100,-100)
 check(AviaRules.shot_hit(shooter,victim),"server ray hits target ahead")
 victim.p=Vector3(30,100,-100);check(not AviaRules.shot_hit(shooter,victim),"server ray rejects off-axis target")
 victim.p=Vector3(0,100,100);check(not AviaRules.shot_hit(shooter,victim),"server ray rejects target behind")
 var wire_player: Dictionary={"state":AviaFlight.spawn(2),"ack":37,"race":{"next":2,"start":95,"time":3.25},"score":4}
 var packed: PackedByteArray=AviaWire.pack({123:wire_player})
 var decoded: Dictionary=AviaWire.unpack(packed)
 check(packed.size()==84 and decoded.has(123) and decoded[123].state.p.distance_to(wire_player.state.p)<0.001 and decoded[123].ack==37 and decoded[123].score==4,"fixed-width snapshot roundtrip")
 check(AviaWire.unpack(PackedByteArray([1,2,3])).is_empty(),"truncated snapshot rejected")
 var malformed: PackedByteArray=packed.duplicate();malformed.encode_float(12,NAN)
 check(AviaWire.unpack(malformed).is_empty(),"nonfinite snapshot rejected")
 var touch: Control=load("res://client/touch.gd").new();root.add_child(touch);touch.size=Vector2(1280,720)
 var centers: Array=touch.centers()
 var first: InputEventScreenTouch=InputEventScreenTouch.new();first.index=1;first.position=centers[0]+Vector2(30,-40);first.pressed=true;touch._input(first)
 var second: InputEventScreenTouch=InputEventScreenTouch.new();second.index=2;second.position=centers[1]-Vector2(0,70);second.pressed=true;touch._input(second)
 var third: InputEventScreenTouch=InputEventScreenTouch.new();third.index=3;third.position=Vector2(centers[1].x,390);third.pressed=true;touch._input(third)
 var simultaneous: Dictionary=touch.command()
 check(simultaneous.pitch>0 and simultaneous.roll>0 and simultaneous.throttle>0.8 and simultaneous.fire,"three synthetic touch pointers operate independently")
 first.pressed=false;first.position=Vector2(-300,-300);touch._input(first)
 check(touch.stick_id==-1 and touch.stick==Vector2.ZERO and touch.throttle_id==2,"release outside captured stick preserves throttle")
 touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(touch.stick_id==-1 and touch.throttle_id==-1 and touch.action_id==-1 and touch.throttle==0 and not touch.fire,"focus loss clears all touches and thrust")
 print(JSON.stringify({"event":"test_summary","checks":checks,"failed":failed,"scope":"Godot shared simulation and synthetic touch; not physical device"}))
 quit(1 if failed else 0)
