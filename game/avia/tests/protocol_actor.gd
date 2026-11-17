extends SceneTree
var session: Node
var scenario: String="invalid"
var options: Dictionary={}
var elapsed: float=0
var sent: bool=false
var tick_sent: bool=false
var begin: Dictionary={}
func _initialize() -> void:
 _start.call_deferred()
func _start() -> void:
 for arg: String in OS.get_cmdline_user_args():
  var pair: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
  options[pair[0]]=pair[1] if pair.size()>1 else "true"
 scenario=options.get("scenario","invalid")
 var parent: Node=Node.new();parent.name="Avia";root.add_child(parent)
 session=load("res://tests/admission_actor.gd" if scenario in ["replay","expired","version"] else "res://net/session.gd").new();session.name="Session";parent.add_child(session)
 if scenario in ["replay","expired","version"]:session.scenario=scenario
 if scenario in ["plain","wrong-cert"]:
  session.peer=ENetMultiplayerPeer.new()
  if scenario=="plain":session.peer.create_client("127.0.0.1",int(options.port),3)
  else:
   session.peer.create_mesh(2);session.connection=ENetConnection.new();session.connection.create_host(1,6)
   session.connection.dtls_client_setup("game-avia.local",TLSOptions.client())
   session.connection.connect_to_host("127.0.0.1",int(options.port),6,2);session.waiting_connection=true;session.last_snapshot_ms=Time.get_ticks_msec()
  session.multiplayer.multiplayer_peer=session.peer
 else:
  session.connect_to("127.0.0.1",int(options.port),{"plane":0,"mode":"free","private":false})
func _process(delta: float) -> bool:
 elapsed+=delta
 if session.joined and not sent and elapsed>1.0:
  sent=true;begin=session.local_state.duplicate()
  if scenario=="invalid":
   session.set_physics_process(false)
   _attack()
  elif scenario=="held-recovery":session.controls.respawn=true
  elif scenario=="rapid-leave":session.disconnect_session()
 if elapsed>=6:
  var ok: bool=not session.joined if scenario in ["plain","expired","wrong-cert","rapid-leave","version"] else session.joined
  if scenario in ["replay","expired"]:ok=ok and session.offered
  if scenario=="version":ok=ok and session.status=="Version mismatch"
  if scenario=="held-recovery":ok=ok and int(session.local_state.get("age",0))>90
  if scenario=="plain":ok=ok and session.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED
  if scenario=="invalid":ok=ok and not session.local_state.is_empty() and session.local_state.p.distance_to(begin.p)<0.1
  print(JSON.stringify({"event":"actor_summary","scenario":scenario,"joined":session.joined,"connection_status":session.status,"snapshots":session.snapshots,"status":"PASS" if ok else "FAIL"}))
  quit(0 if ok else 1)
 return false

func _attack() -> void:
 var c: Dictionary=AviaFlight.neutral()
 var number: int=int(session.seq)+2
 for bad: float in [NAN,INF,3.0]:
  c.pitch=bad;session.command.rpc_id(1,number,c)
  await create_timer(0.2).timeout
 c=AviaFlight.neutral();c.position=Vector3(4000,2000,4000);session.command.rpc_id(1,number,c)
 await create_timer(0.2).timeout
 c=AviaFlight.neutral();session.command.rpc_id(1,-10,c)
 await create_timer(0.2).timeout
 session.command.rpc_id(1,number+10000,c)
 await create_timer(0.2).timeout
 session.redeem_ticket.rpc_id(1,"0".repeat(48))
