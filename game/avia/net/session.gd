extends Node
## Server authority. No client position/score RPC exists. Separate reliable/control/state channels.
const PROTOCOL: int=4
const MAX_ROOM: int=16
var tickets: Dictionary={}
var ticket_rate: Dictionary={}
var transport: String="ENet/DTLS"
var waiting_connection: bool=false
var connection: ENetConnection
var server: bool=false
var peer: ENetMultiplayerPeer
var players: Dictionary={}
var rooms: Dictionary={}
var local_state: Dictionary={}
var local_race: Dictionary={}
var local_score: int=0
var others: Dictionary={}
var pending: Array[Dictionary]=[]
var seq: int=0
var tick: int=0
var status: String="Menu"
var last_error: String=""
var recover_down: bool=false
var recover_number: int=0
var joined: bool=false
var mode: String="free"
var room: String=""
var plane: int=0
var controls: Dictionary=AviaFlight.neutral()
var notices: Array[String]=[]
var visual_offset: Vector3=Vector3.ZERO
var corrections: Array[float]=[]
var correction_max: float=0.0
var snapshots: int=0
var accepted: int=0
var rejected: int=0
var seen_peers: int=0
var tick_us: Array[int]=[]
var totals: Dictionary={"flights":0,"landings":0,"races":0,"best_race_seconds":0.0}
var stats_path: String="user://server-progress.json"
var clock_offset_ms: float=0.0
var server_tick_seen: int=-1
var last_snapshot_ms: int=0
var join_options: Dictionary={}
var diagnostics: bool=false
var diagnostic_last_ms: int=0
var diagnostic_frames: int=0
var diagnostic_physics: int=0
var commands_sent: int=0
signal state_audit(peer_id: int, state: Dictionary, ack: int)
signal input_audit(peer_id: int, number: int, result: String)
signal admission_audit(peer_id: int, result: String)
signal message(text: String)

func start_server(port: int) -> Error:
 server=true
 peer=ENetMultiplayerPeer.new()
 var result: Error=peer.create_server(port,64,3)
 if result!=OK:return result
 # Godot ed1daf0bf create_server forwards max_channels+SYSCH_MAX as incoming bandwidth.
 # Restore the intended uncapped host bandwidth and six total channels explicitly.
 peer.host.bandwidth_limit(0,0)
 peer.host.channel_limit(6)
 var key: CryptoKey=CryptoKey.new()
 var cert: X509Certificate=X509Certificate.new()
 var key_path: String=OS.get_environment("AVIA_DTLS_KEY")
 if key_path.is_empty() or key.load(key_path)!=OK or cert.load("res://net/server.crt")!=OK:peer.close();return ERR_UNCONFIGURED
 result=peer.host.dtls_server_setup(TLSOptions.server(key,cert))
 if result!=OK:peer.close();return result
 multiplayer.server_relay=false
 multiplayer.multiplayer_peer=peer
 multiplayer.peer_disconnected.connect(_departed)
 multiplayer.peer_connected.connect(_connected)
 if FileAccess.file_exists(stats_path):
  var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(stats_path))
  if saved is Dictionary:totals.merge(saved,true)
 status="Server ready"
 print(JSON.stringify({"event":"server_ready","port":port,"protocol":PROTOCOL,"headless":DisplayServer.get_name()=="headless","transport":transport}))
 return OK
func connect_to(host: String, port: int, options: Dictionary) -> Error:
 disconnect_session()
 server=false
 last_error="";recover_down=false;recover_number=0
 plane=int(options.get("plane",0));mode=str(options.get("mode","free"));join_options=options
 peer=ENetMultiplayerPeer.new()
 var bytes: PackedByteArray=Crypto.new().generate_random_bytes(4)
 var client_id: int=maxi(2,int(bytes.decode_u32(0) & 0x7fffffff))
 var result: Error=peer.create_mesh(client_id)
 if result!=OK:return result
 connection=ENetConnection.new()
 result=connection.create_host(1,6)
 if result!=OK:return result
 var cert: X509Certificate=X509Certificate.new()
 if cert.load("res://net/server.crt")!=OK:return ERR_UNCONFIGURED
 # DTLS must be configured BEFORE connect_to_host (Godot 4.7 API contract).
 result=connection.dtls_client_setup("game-avia.local",TLSOptions.client(cert))
 if result!=OK:return result
 var remote: ENetPacketPeer=connection.connect_to_host(host,port,6,client_id)
 if remote==null:return ERR_CANT_CONNECT
 multiplayer.server_relay=false
 multiplayer.multiplayer_peer=peer
 if not multiplayer.peer_disconnected.is_connected(_client_peer_departed):multiplayer.peer_disconnected.connect(_client_peer_departed)
 waiting_connection=true
 status="Connecting"
 last_snapshot_ms=Time.get_ticks_msec()
 return OK
func _client_peer_departed(id: int) -> void:
 if id==1:_connection_failed()
func _process(_delta: float) -> void:
 diagnostic_frames+=1
 if diagnostics and Time.get_ticks_msec()-diagnostic_last_ms>=2000:
  diagnostic_last_ms=Time.get_ticks_msec()
  print(JSON.stringify({"event":"client_loop","wall_ms":diagnostic_last_ms,"frames":diagnostic_frames,"physics":diagnostic_physics,"sent":commands_sent,"acked":seq-pending.size(),"pending":pending.size(),"snapshots":snapshots,"joined":joined,"status":status,"throttle":controls.throttle}))
 if not waiting_connection:return
 var event: Array=connection.service(0)
 if event[0]==ENetConnection.EVENT_CONNECT:
  waiting_connection=false
  var result: Error=peer.add_mesh_peer(1,connection)
  if result==OK:_on_connected()
  else:_connection_failed()
 elif event[0] in [ENetConnection.EVENT_ERROR,ENetConnection.EVENT_DISCONNECT] or Time.get_ticks_msec()-last_snapshot_ms>8000:
  waiting_connection=false;_connection_failed()
func disconnect_session(reason: String="Menu") -> void:
 joined=false
 if waiting_connection and connection:connection.destroy()
 waiting_connection=false
 # Detach the API before closing to avoid a delayed departure replacing a specific error.
 multiplayer.multiplayer_peer=null
 if peer:peer.close();peer=null
 connection=null
 pending.clear();others.clear();local_state.clear();local_race.clear()
 controls=AviaFlight.neutral();visual_offset=Vector3.ZERO;recover_down=false
 seq=0;server_tick_seen=-1;room="";local_score=0;status=reason
func _notification(what: int) -> void:
 if not server and what==NOTIFICATION_APPLICATION_PAUSED:
  disconnect_session("Paused — reconnect from menu")
func _on_connected() -> void:
 status="Joining"
 last_snapshot_ms=Time.get_ticks_msec()
 request_ticket.rpc_id(1,PROTOCOL,plane,mode,str(join_options.get("code","")),bool(join_options.get("private",false)),int(join_options.get("profile",0)))
func _connection_failed() -> void:
 disconnect_session(last_error if not last_error.is_empty() else "Disconnected — retry from menu");message.emit(status)
func _connected(id: int) -> void:
 # Unauthenticated connections get five seconds, then are removed.
 get_tree().create_timer(5.0).timeout.connect(func():
  if peer and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and not players.has(id) and id in multiplayer.get_peers():peer.disconnect_peer(id))
func _departed(id: int) -> void:
 tickets.erase(id);ticket_rate.erase(id)
 if not players.has(id):return
 var key: String=players[id].room
 players.erase(id)
 _broadcast.call_deferred(key,"departure",{"id":id})
 if not _room_count(key):rooms.erase(key)
func _room_count(key: String) -> int:
 var count: int=0
 for p: Dictionary in players.values():
  if p.room==key:count+=1
 return count
func _persist() -> void:
 var file: FileAccess=FileAccess.open(stats_path+".tmp",FileAccess.WRITE)
 if file==null:push_error("progress_write_failed");return
 file.store_string(JSON.stringify(totals));file.flush();file.close()
 var result: Error=DirAccess.rename_absolute(stats_path+".tmp",stats_path)
 if result!=OK:push_error("progress_publish_failed")
func _broadcast(key: String, kind: String, data: Dictionary) -> void:
 for id: int in players:
  if players[id].room==key and peer.get_peer(id).get_state()==ENetPacketPeer.STATE_CONNECTED and peer.get_peer(id).get_channels()>2:game_event.rpc_id(id,kind,data)
 print(JSON.stringify({"event":kind,"room":key,"data":data,"tick":tick}))
@rpc("any_peer","call_remote","reliable",0)
func request_ticket(version: int, selected: int, requested_mode: String, code: String, private_room: bool, requested_profile: int=0) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 if players.has(id) or (ticket_rate.has(id) and tick-int(ticket_rate[id])<30):rejected+=1;return
 ticket_rate[id]=tick
 if code.length()>12:rejected+=1;return
 var token: String=Crypto.new().generate_random_bytes(24).hex_encode()
 tickets[id]={"token":token,"expires":tick+90,"options":[version,selected,requested_mode,code,private_room,requested_profile]}
 admission_ticket.rpc_id(id,token)
@rpc("authority","call_remote","reliable",0)
func admission_ticket(token: String) -> void:
 if server:return
 redeem_ticket.rpc_id(1,token)
@rpc("any_peer","call_remote","reliable",0)
func redeem_ticket(token: String) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 var reason: String="accepted"
 if token.length()!=48 or not tickets.has(id):reason="missing_ticket"
 elif tick>int(tickets[id].expires):reason="expired_ticket"
 elif token!=tickets[id].token:reason="wrong_ticket"
 if admission_audit.has_connections():admission_audit.emit(id,reason)
 if reason!="accepted":rejected+=1;return
 var ticket: Dictionary=tickets[id]
 tickets.erase(id)
 var o: Array=ticket.options
 _admit(id,int(o[0]),int(o[1]),str(o[2]),str(o[3]),bool(o[4]),int(o[5]))
func _admit(id: int, version: int, selected: int, requested_mode: String, code: String, private_room: bool, requested_profile: int=0) -> void:
 if not server:return
 if players.has(id):return
 if version!=PROTOCOL:
  game_event.rpc_id(id,"error",{"reason":"Version mismatch"});return
 if requested_profile<0 or requested_profile>2:
  rejected+=1;game_event.rpc_id(id,"error",{"reason":"Invalid flight profile"});return
 if selected<0 or selected>=AviaFlight.PLANES.size() or requested_mode not in ["free","race","pvp"] or code.length()>12:
  rejected+=1;return
 for ch: String in code:
  if not ch in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789":
   rejected+=1;game_event.rpc_id(id,"error",{"reason":"Invalid room code"});return
 if private_room and code.length()<4:
  game_event.rpc_id(id,"error",{"reason":"Private code needs 4–12 uppercase letters/digits"});return
 var key: String="private:"+code if private_room else "public:"+requested_mode+":0"
 if not private_room:
  var index: int=0
  while _room_count(key)>=MAX_ROOM:
   index+=1;key="public:"+requested_mode+":"+str(index)
 if _room_count(key)>=MAX_ROOM:
  game_event.rpc_id(id,"error",{"reason":"Room full"});return
 if rooms.has(key) and rooms[key]!=requested_mode:
  game_event.rpc_id(id,"error",{"reason":"Room mode mismatch"});return
 rooms[key]=requested_mode
 var state: Dictionary=AviaFlight.spawn(selected,_room_count(key))
 state.profile=requested_profile if requested_mode=="free" else 0
 players[id]={"state":state,"input":AviaFlight.neutral(),"room":key,"seq":0,"ack":0,"last":tick,"window":tick,
 "recover_pending":false,"recover_seq":0,"recover_tick":-90,"packets":0,"race":{"next":0},"score":0,"last_shot":-30,"crash_tick":-1,"callsign":"Pilot-"+str(id % 10000)}
 game_event.rpc_id(id,"welcome",{"id":id,"room":key,"mode":requested_mode,"state":state,"protocol":PROTOCOL})
 _broadcast(key,"arrival",{"id":id,"callsign":players[id].callsign})
@rpc("any_peer","call_remote","unreliable_ordered",1)
func command(number: int, input: Dictionary) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 var reason: String="accepted"
 if not players.has(id):reason="not_admitted"
 else:
  var p: Dictionary=players[id]
  if tick-int(p.window)>=30:p.window=tick;p.packets=0
  p.packets+=1
  if int(p.packets)>65:reason="rate"
  elif number<=int(p.seq):reason="replayed_sequence"
  elif number>int(p.seq)+120:reason="sequence_jump"
  elif not AviaFlight.valid_input(input):reason="invalid_input"
  if reason=="accepted":p.input=input;p.seq=number;p.last=tick;accepted+=1
 if reason!="accepted":rejected+=1
 if input_audit.has_connections():input_audit.emit(id,number,reason)
@rpc("any_peer","call_remote","reliable",0)
func recover(number: int) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 if not players.has(id):rejected+=1;return
 var p: Dictionary=players[id]
 if number<=int(p.recover_seq) or number>int(p.recover_seq)+120:rejected+=1;return
 p.recover_seq=number
 if tick-int(p.recover_tick)<30:rejected+=1;return
 p.recover_tick=tick;p.recover_pending=true
@rpc("authority","call_remote","reliable",0)
func game_event(kind: String, data: Dictionary) -> void:
 if server:return
 if kind=="welcome":
  last_snapshot_ms=Time.get_ticks_msec()
  joined=true;room=data.room;mode=data.mode;local_state=data.state;status="Connected"
 elif kind=="error":last_error=str(data.reason);disconnect_session(last_error)
 elif kind=="departure":others.erase(int(data.id))
 var line: String=kind+" "+str(data)
 if kind!="welcome":
  notices.append(line);if notices.size()>5:notices.pop_front()
 message.emit(line)
 print(JSON.stringify({"event":kind,"peer":multiplayer.get_unique_id(),"data":data}))
@rpc("authority","call_remote","unreliable_ordered",2)
func snapshot(server_tick: int, packed: PackedByteArray, progress: Dictionary) -> void:
 if server or not joined or server_tick<=server_tick_seen:return
 var states: Dictionary=AviaWire.unpack(packed)
 if states.is_empty():return
 var now: int=Time.get_ticks_msec()
 var half_rtt: float=peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)*0.5
 var offset: float=server_tick/30.0*1000.0+half_rtt-now
 clock_offset_ms=offset if server_tick_seen<0 else lerpf(clock_offset_ms,offset,0.1)
 server_tick_seen=server_tick;snapshots+=1;last_snapshot_ms=now
 seen_peers=maxi(seen_peers,states.size())
 totals=progress
 var mine: int=multiplayer.get_unique_id()
 if states.has(mine):
  local_race=states[mine].race;local_score=int(states[mine].score)
  var base: Dictionary=states[mine].state.duplicate()
  var ack: int=int(states[mine].ack)
  while not pending.is_empty() and int(pending[0].seq)<=ack:pending.pop_front()
  for item: Dictionary in pending:base=AviaFlight.step(base,item.input)
  if not local_state.is_empty():
   var error: float=local_state.p.distance_to(base.p)
   corrections.append(error)
   if corrections.size()>27000:corrections.pop_front()
   correction_max=maxf(correction_max,error)
   if error<25.0 and not base.crashed and base.age>=local_state.age-5:
    visual_offset=(visual_offset+local_state.p-base.p).limit_length(20.0)
   else:visual_offset=Vector3.ZERO
   if error>25:print(JSON.stringify({"event":"large_correction","metres":error,"tick":server_tick}))
  local_state=base
 for id: int in states:
  if id==mine:continue
  var state: Dictionary=states[id].state
  if not others.has(id):others[id]=[]
  var buffer: Array=others[id]
  buffer.append({"tick":server_tick,"state":state})
  if buffer.size()>8:buffer.pop_front()
 for id: int in others.keys():
  if not states.has(id):others.erase(id)
func remote_state(id: int) -> Dictionary:
 var buffer: Array=others[id]
 var latest: Dictionary=buffer[-1].state
 var render_tick: float=(Time.get_ticks_msec()+clock_offset_ms)/1000.0*30.0-3.0
 for i: int in range(1,buffer.size()):
  if float(buffer[i].tick)>=render_tick:
   var a: Dictionary=buffer[i-1];var b: Dictionary=buffer[i]
   var t: float=clampf((render_tick-float(a.tick))/float(b.tick-a.tick),0.0,1.0)
   var result: Dictionary=b.state.duplicate()
   result.p=a.state.p.lerp(b.state.p,t)
   for axis: String in ["pitch","yaw","roll"]:result[axis]=lerp_angle(float(a.state[axis]),float(b.state[axis]),t)
   return result
 var extrapolated: Dictionary=latest.duplicate()
 extrapolated.p+=latest.v*clampf((render_tick-float(buffer[-1].tick))/30.0,0.0,0.15)
 return extrapolated
func _physics_process(_delta: float) -> void:
 diagnostic_physics+=1
 if server:
  var start: int=Time.get_ticks_usec()
  tick+=1
  for id: int in players.keys():
   var p: Dictionary=players[id]
   if tick-int(p.last)>300:peer.disconnect_peer(id);_departed(id);continue
   var c: Dictionary=p.input if tick-int(p.last)<=15 else AviaFlight.neutral()
   var before: Dictionary=p.state
   if p.recover_pending and (not before.crashed or tick-int(p.crash_tick)>45):
    p.recover_pending=false
    p.state=AviaFlight.spawn(before.plane,0);p.state.profile=before.profile;p.race={"next":0}
    _broadcast(p.room,"respawn",{"id":id})
   else:p.state=AviaFlight.step(before,c)
   p.ack=p.seq
   if state_audit.has_connections():state_audit.emit(id,p.state,p.ack)
   if not before.was_airborne and p.state.was_airborne:
    totals.flights+=1;_persist();_broadcast(p.room,"takeoff",{"id":id})
   if p.state.landed:totals.landings+=1;_persist();_broadcast(p.room,"landing",{"id":id})
   if not before.crashed and p.state.crashed:
    p.crash_tick=tick;_broadcast(p.room,"crash",{"id":id})
   var active_mode: String=rooms[p.room]
   if active_mode=="race" and not p.state.crashed:
    var event: String=AviaRules.race_tick(p.race,before.p,p.state.p,tick)
    if not event.is_empty():
     if event=="finish":
      totals.races+=1
      if float(totals.best_race_seconds)==0 or float(p.race.time)<float(totals.best_race_seconds):totals.best_race_seconds=p.race.time
      _persist()
     _broadcast(p.room,event,{"id":id,"next":p.race.next,"seconds":p.race.get("time",0)})
   if active_mode=="pvp" and c.fire and not p.state.crashed and tick-int(p.last_shot)>=6:
    p.last_shot=tick
    _broadcast(p.room,"shot",{"id":id})
    for victim: int in players:
     if victim==id or players[victim].room!=p.room or players[victim].state.crashed:continue
     var target: Dictionary=players[victim].state
     if AviaRules.shot_hit(p.state,target):
      target.health=maxf(0.0,float(target.health)-25.0)
      _broadcast(p.room,"hit",{"id":victim,"health":target.health,"by":id})
      if target.health<=0:
       target.crashed=true;target.v=Vector3.ZERO;players[victim].crash_tick=tick;p.score+=1
       _broadcast(p.room,"score",{"id":id,"score":p.score})
      break
  if tick % 2==0:
   for id: int in players:
    if peer.get_peer(id).get_state()!=ENetPacketPeer.STATE_CONNECTED or peer.get_peer(id).get_channels()<3:continue
    var visible: Dictionary={}
    for other: int in players:
     if players[id].room==players[other].room and (id==other or players[id].state.p.distance_to(players[other].state.p)<4500.0):
      visible[other]={"state":players[other].state,"ack":players[other].ack,"race":players[other].race,"score":players[other].score}
    snapshot.rpc_id(id,tick,AviaWire.pack(visible),totals)
  tick_us.append(Time.get_ticks_usec()-start)
  if tick_us.size()>54000:tick_us.pop_front()
  if tick % 300==0:
   var sorted: Array[int]=tick_us.duplicate();sorted.sort()
   print(JSON.stringify({"event":"health","tick":tick,"connections":players.size(),"accepted":accepted,"rejected":rejected,"tick_p95_ms":float(sorted[int(sorted.size()*0.95)])/1000.0,"totals":totals,"sent_bytes_10s":peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA),"received_bytes_10s":peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)}))
 elif joined and not local_state.is_empty():
  visual_offset*=0.78
  if controls.respawn and not recover_down:
   recover_number+=1;recover.rpc_id(1,recover_number)
  recover_down=controls.respawn
  seq+=1
  command.rpc_id(1,seq,controls);commands_sent+=1
  pending.append({"seq":seq,"input":controls.duplicate()})
  if pending.size()>90:
   disconnect_session("Network timeout — retry from menu");return
  local_state=AviaFlight.step(local_state,controls)
  if Time.get_ticks_msec()-last_snapshot_ms>5000:
   disconnect_session("Network timeout — retry from menu")
