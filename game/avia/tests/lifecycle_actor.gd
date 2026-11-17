extends SceneTree
var session: Node
var world: Node3D
var checks: Array[Dictionary]=[]
func check(ok: bool, label: String) -> void:
 checks.append({"check":label,"ok":ok})
func _initialize() -> void:_run.call_deferred()
func wait_join() -> bool:
 var deadline: int=Time.get_ticks_msec()+5000
 while not session.joined and Time.get_ticks_msec()<deadline:await process_frame
 return session.joined
func _run() -> void:
 var parent: Node=Node.new();parent.name="Avia";root.add_child(parent)
 session=load("res://net/session.gd").new();session.name="Session";parent.add_child(session)
 world=load("res://client/world.gd").new();parent.add_child(world)
 session.connect_to("127.0.0.1",24576,{"plane":0,"mode":"free"})
 check(await wait_join(),"initial real ENet/DTLS admission")
 if session.joined:
  world.update_session(session,0.03)
  check(world.planes.size()==1,"admitted aircraft rendered in scene graph")
  session._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
  world.update_session(session,0.03)
  check(not session.joined and session.status=="Paused — reconnect from menu" and world.planes.is_empty() and not world.camera_ready and session.pending.is_empty() and session.controls.throttle==0,"background detaches transport, clears prediction/visuals/controls, preserves reason")
  session.connect_to("127.0.0.1",24576,{"plane":1,"mode":"free"})
  check(await wait_join() and session.local_state.get("plane",-1)==1,"real reconnect with changed aircraft")
  if session.joined:
   session.last_snapshot_ms=Time.get_ticks_msec()-6000
   session._check_snapshot_timeout()
   check(not session.joined and session.status=="Network timeout — retry from menu","snapshot timeout preserves actionable error")
  session.connect_to("127.0.0.1",24576,{"plane":2,"mode":"free"})
  check(await wait_join(),"real reconnect after timeout")
  if session.joined:
   await create_timer(0.3).timeout
   var previous_tick: int=session.server_tick_seen;var previous_snapshots: int=session.snapshots
   OS.delay_msec(5500) # Only this test client stalls; real server keeps ticking.
   session._physics_process(AviaFlight.DT)
   session._process(0.0)
   check(session.joined and session.snapshots>previous_snapshots and session.server_tick_seen>=previous_tick+140,"real queued snapshots drained before timeout after5.5s client frame stall; server clock continued")
  session.disconnect_session();world.update_session(session,0.03)
  check(session.status=="Menu" and session.local_state.is_empty() and session.others.is_empty() and world.planes.is_empty(),"intentional leave clears scene and returns Menu")
 var ok: bool=checks.all(func(c: Dictionary):return c.ok)
 print(JSON.stringify({"event":"lifecycle_summary","checks":checks,"status":"PASS" if ok else "FAIL","scope":"real desktop headless connections, actual5.5s stalled client with separate running server, synthetic lifecycle notifications; not Android OS lifecycle"}))
 quit(0 if ok else 1)
