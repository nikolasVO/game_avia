extends Node
## Server authority. No client position/score RPC exists. Separate reliable/control/state channels.
const PROTOCOL: int=1
const MAX_ROOM: int=16
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
var joined: bool=false
var mode: String="free"
var room: String=""
var plane: int=0
var controls: Dictionary=AviaFlight.neutral()
var notices: Array[String]=[]
var correction_max: float=0.0
var snapshots: int=0
var accepted: int=0
var rejected: int=0
var seen_peers: int=0
var tick_us: Array[int]=[]
var totals: Dictionary={"flights":0,"landings":0,"races":0,"best_race_seconds":0.0}
var stats_path: String="user://server-progress.json"
var server_tick_seen: int=-1
var last_snapshot_ms: int=0
var join_options: Dictionary={}
signal message(text: String)

func start_server(port: int) -> Error:
 server=true
 peer=ENetMultiplayerPeer.new()
 var result: Error=peer.create_server(port,64,3)
 if result!=OK:return result
 multiplayer.multiplayer_peer=peer
 multiplayer.peer_disconnected.connect(_departed)
 multiplayer.peer_connected.connect(_connected)
 if FileAccess.file_exists(stats_path):
  var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(stats_path))
  if saved is Dictionary:totals.merge(saved,true)
 status="Server ready"
 print(JSON.stringify({"event":"server_ready","port":port,"protocol":PROTOCOL,"headless":DisplayServer.get_name()=="headless"}))
 return OK
func connect_to(host: String, port: int, options: Dictionary) -> Error:
 disconnect_session()
 server=false
 plane=int(options.get("plane",0)); mode=str(options.get("mode","free"))
 join_options=options
 peer=ENetMultiplayerPeer.new()
 var result: Error=peer.create_client(host,port,3)
 if result!=OK:status="Connection failed";return result
 multiplayer.multiplayer_peer=peer
 if not multiplayer.connected_to_server.is_connected(_on_connected):
  multiplayer.connected_to_server.connect(_on_connected)
  multiplayer.connection_failed.connect(_connection_failed)
  multiplayer.server_disconnected.connect(_connection_failed)
 status="Connecting"
 last_snapshot_ms=Time.get_ticks_msec()
 return OK
func disconnect_session() -> void:
 joined=false
 if peer:peer.close()
 multiplayer.multiplayer_peer=null
 pending.clear();others.clear();local_state.clear()
 seq=0;server_tick_seen=-1
func _on_connected() -> void:
 status="Joining"
 join_game.rpc_id(1,PROTOCOL,plane,mode,str(join_options.get("code","")),bool(join_options.get("private",false)))
func _connection_failed() -> void:
 joined=false;status="Disconnected — retry from menu";message.emit(status)
func _connected(id: int) -> void:
 # Unauthenticated connections get five seconds, then are removed.
 get_tree().create_timer(5.0).timeout.connect(func():
  if peer and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and not players.has(id):peer.disconnect_peer(id))
func _departed(id: int) -> void:
 if not players.has(id):return
 var key: String=players[id].room
 players.erase(id)
 _broadcast(key,"departure",{"id":id})
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
  if players[id].room==key and peer.get_peer(id).get_state()==ENetPacketPeer.STATE_CONNECTED:game_event.rpc_id(id,kind,data)
 print(JSON.stringify({"event":kind,"room":key,"data":data,"tick":tick}))
@rpc("any_peer","call_remote","reliable",0)
func join_game(version: int, selected: int, requested_mode: String, code: String, private_room: bool) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 if players.has(id):return
 if version!=PROTOCOL:
  game_event.rpc_id(id,"error",{"reason":"Version mismatch"});return
 if selected<0 or selected>=AviaFlight.PLANES.size() or requested_mode not in ["free","race","pvp"] or code.length()>12:
  rejected+=1;return
 for ch: String in code:
  if not ch in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789": rejected+=1;return
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
 players[id]={"state":state,"input":AviaFlight.neutral(),"room":key,"seq":0,"ack":0,"last":tick,"window":tick,
 "packets":0,"race":{"next":0},"score":0,"last_shot":-30,"crash_tick":-1,"callsign":"Pilot-"+str(id % 10000)}
 game_event.rpc_id(id,"welcome",{"id":id,"room":key,"mode":requested_mode,"state":state,"protocol":PROTOCOL})
 _broadcast(key,"arrival",{"id":id,"callsign":players[id].callsign})
@rpc("any_peer","call_remote","unreliable_ordered",1)
func command(number: int, input: Dictionary) -> void:
 if not server:return
 var id: int=multiplayer.get_remote_sender_id()
 if not players.has(id):rejected+=1;return
 var p: Dictionary=players[id]
 if tick-int(p.window)>=30:p.window=tick;p.packets=0
 p.packets+=1
 if int(p.packets)>65 or number<=int(p.seq) or number>int(p.seq)+120 or not AviaFlight.valid_input(input):
  rejected+=1;return
 p.input=input;p.seq=number;p.last=tick;accepted+=1
@rpc("authority","call_remote","reliable",0)
func game_event(kind: String, data: Dictionary) -> void:
 if server:return
 if kind=="welcome":
  joined=true;room=data.room;mode=data.mode;local_state=data.state;status="Connected"
 elif kind=="error":status=str(data.reason);joined=false
 elif kind=="departure":others.erase(int(data.id))
 var line: String=kind+" "+str(data)
 if kind!="welcome":
  notices.append(line);if notices.size()>5:notices.pop_front()
 message.emit(line)
 print(JSON.stringify({"event":kind,"peer":multiplayer.get_unique_id(),"data":data}))
@rpc("authority","call_remote","unreliable_ordered",2)
func snapshot(server_tick: int, states: Dictionary, progress: Dictionary) -> void:
 if server or not joined or server_tick<=server_tick_seen:return
 server_tick_seen=server_tick;snapshots+=1;last_snapshot_ms=Time.get_ticks_msec()
 seen_peers=maxi(seen_peers,states.size())
 totals=progress
 var mine: int=multiplayer.get_unique_id()
 if states.has(mine):
  local_race=states[mine].race;local_score=int(states[mine].score)
  var base: Dictionary=states[mine].state.duplicate()
  var ack: int=int(states[mine].ack)
  while not pending.is_empty() and int(pending[0].seq)<=ack:pending.pop_front()
  for item: Dictionary in pending:base=AviaFlight.step(base,item.input)
  if not local_state.is_empty():correction_max=maxf(correction_max,local_state.p.distance_to(base.p))
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
 var render_tick: float=float(server_tick_seen)+(Time.get_ticks_msec()-last_snapshot_ms)/1000.0*30.0-3.0
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
 if server:
  var start: int=Time.get_ticks_usec()
  tick+=1
  for id: int in players.keys():
   var p: Dictionary=players[id]
   if tick-int(p.last)>300:peer.disconnect_peer(id);_departed(id);continue
   var c: Dictionary=p.input if tick-int(p.last)<=15 else AviaFlight.neutral()
   var before: Dictionary=p.state
   if c.respawn and (not before.crashed or tick-int(p.crash_tick)>45):
    p.state=AviaFlight.spawn(before.plane,0);p.race={"next":0};p.input.respawn=false
    _broadcast(p.room,"respawn",{"id":id})
   else:p.state=AviaFlight.step(before,c)
   p.ack=p.seq
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
    var visible: Dictionary={}
    for other: int in players:
     if players[id].room==players[other].room and (id==other or players[id].state.p.distance_to(players[other].state.p)<4500.0):
      visible[other]={"state":players[other].state,"ack":players[other].ack,"race":players[other].race,"score":players[other].score}
    snapshot.rpc_id(id,tick,visible,totals)
  tick_us.append(Time.get_ticks_usec()-start)
  if tick_us.size()>54000:tick_us.pop_front()
  if tick % 300==0:
   var sorted: Array[int]=tick_us.duplicate();sorted.sort()
   print(JSON.stringify({"event":"health","tick":tick,"connections":players.size(),"accepted":accepted,"rejected":rejected,"tick_p95_ms":float(sorted[int(sorted.size()*0.95)])/1000.0,"totals":totals,"sent_bytes_10s":peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA),"received_bytes_10s":peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)}))
 elif joined and not local_state.is_empty():
  seq+=1
  command.rpc_id(1,seq,controls)
  pending.append({"seq":seq,"input":controls.duplicate()})
  if pending.size()>90:
   status="Network timeout";disconnect_session();return
  local_state=AviaFlight.step(local_state,controls)
  if Time.get_ticks_msec()-last_snapshot_ms>5000:
   status="Network timeout";disconnect_session()
