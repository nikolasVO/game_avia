extends Node3D
var planes: Dictionary={}
var camera_offset: Vector3=Vector3.ZERO
var checkpoint_nodes: Array[MeshInstance3D]=[]
var camera: Camera3D
var camera_ready: bool=false
signal camera_mode_changed
enum CameraMode { CHASE, FORWARD, ORBIT, COCKPIT }
var camera_mode: int=CameraMode.CHASE
var cockpit: bool:
 get:return camera_mode==CameraMode.COCKPIT
var cockpit_shell: Node3D
var look_pitch: float=0.0
var camera_zoom: float=1.0
var instrument_speed_unit: int=0
var instrument_altitude_unit: int=0
var instrument_throttle: float=0.0
var language: String="en"
var reduced_motion: bool=false
var orbit: float=0.0
func material(color: Color) -> StandardMaterial3D:
 var m: StandardMaterial3D=StandardMaterial3D.new()
 m.albedo_color=color;m.roughness=0.85;m.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
 return m
func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var node: MeshInstance3D=MeshInstance3D.new()
 var mesh: BoxMesh=BoxMesh.new();mesh.size=size
 node.mesh=mesh;node.material_override=material(color);node.position=pos
 parent.add_child(node);return node
func _ready() -> void:
 var env_node: WorldEnvironment=WorldEnvironment.new()
 var env: Environment=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("8ab7ca")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d0e1ea");env.ambient_light_energy=0.7
 env.fog_enabled=true;env.fog_light_color=Color("91b5c6");env.fog_density=0.00016
 env_node.environment=env;add_child(env_node)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-24,0);sun.light_energy=1.3;sun.shadow_enabled=false;add_child(sun)
 box(self,Vector3(0,-6,0),Vector3(14000,2,14000),Color("367e99"))
 # Height mesh uses the same function as authoritative swept collision.
 var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var n: int=100;var spacing: float=36.0
 for x: int in range(n):
  for z: int in range(n):
   var a: Vector3=Vector3((x-n/2)*spacing,0,(z-n/2)*spacing)
   var b: Vector3=a+Vector3(spacing,0,0);var c: Vector3=a+Vector3(0,0,spacing);var d: Vector3=a+Vector3(spacing,0,spacing)
   for triangle: Array in [[a,b,c],[b,d,c]]:
    var vertices: Array[Vector3]=[];var submerged: bool=true
    for v: Vector3 in triangle:
     v.y=AviaFlight.height(v)-0.05
     if v.y>-5:submerged=false
     else:v.y=-7.0 # Hidden sea bed stays clear of the water depth surface.
     vertices.append(v)
    if submerged:continue
    for v: Vector3 in vertices:
     st.set_color(Color("739681") if v.y<30 else Color("879987"));st.add_vertex(v)
 st.generate_normals()
 var terrain: MeshInstance3D=MeshInstance3D.new();terrain.mesh=st.commit()
 var mat: StandardMaterial3D=material(Color.WHITE);mat.vertex_color_use_as_albedo=true;terrain.material_override=mat;add_child(terrain)
 for center: Vector3 in [Vector3.ZERO,Vector3(900,0,-1000)]:
  var length: float=640.0 if center==Vector3.ZERO else 300.0
  box(self,center+Vector3(0,0.08,0),Vector3(56,0.15,length),Color("3c5057"))
  for z: int in range(-int(length/2)+10,int(length/2)-10,35):
   box(self,center+Vector3(0,0.18,z),Vector3(1.3,0.05,15),Color("e9dfc6"))
  for side: int in [-1,1]:
   box(self,center+Vector3(side*25,0.18,0),Vector3(0.6,0.05,length-10),Color("d4ceba"))
 box(self,Vector3(85,8,70),Vector3(36,16,36),Color("c3b48b"))
 box(self,Vector3(85,21,70),Vector3(13,14,13),Color("e2d5ac"))
 box(self,Vector3(85,30,70),Vector3(21,5,21),Color("407c85"))
 for z: int in [0,65,130]:
  box(self,Vector3(-100,8,z),Vector3(45,16,40),Color("b6bca6"))
 # AI safety blocks from the existing image -> TRELLIS -> Blender artifact, outside the strip.
 var catalog: PackedScene=load("res://assets/airfield_safety_block.glb")
 for location: Vector3 in [Vector3(-36,0,160),Vector3(-36,0,162),Vector3(-38,0,161)]:
  var safety: Node3D=AviaCatalogProp.build(catalog);safety.position=location;safety.position.y=AviaFlight.height(location);add_child(safety)
 print(JSON.stringify({"event":"catalog_prop_ready","asset":"airfield_safety_block","source_type":"AI/TRELLIS","instances":3}))
 # Existing verified AI candidate is a parked decorative exhibit, not an accepted fighter.
 var parked: Node3D=AviaCatalogProp.build(load("res://assets/parked_ai_aircraft.glb"))
 parked.position=Vector3(-58,AviaFlight.height(Vector3(-58,0,145)),145);add_child(parked)
 print(JSON.stringify({"event":"catalog_prop_ready","asset":"trellis_validation_plane_20261117","source_type":"AI/TRELLIS","instances":1,"role":"parked_decorative_candidate","production_accepted":false}))
 for p: Vector3 in AviaRules.CHECKPOINTS:
  var ring: MeshInstance3D=MeshInstance3D.new();var torus: TorusMesh=TorusMesh.new()
  torus.inner_radius=AviaRules.RADIUS-2;torus.outer_radius=AviaRules.RADIUS;torus.rings=24;torus.ring_segments=8
  ring.mesh=torus;ring.position=p;ring.rotation.x=PI/2;ring.material_override=material(Color("edc777"));add_child(ring);checkpoint_nodes.append(ring)
 camera=Camera3D.new();camera.near=0.5;camera.far=6500;camera.current=true;add_child(camera)
 cockpit_shell=load("res://client/cockpit.gd").new();add_child(cockpit_shell)
 camera.position=Vector3(90,70,270);camera.look_at(Vector3(0,15,-200))
func make_plane(index: int) -> Node3D:
 return AviaAircraft.build(index)
func update_plane(id: int, state: Dictionary) -> void:
 if not planes.has(id):
  var visual: Node3D=make_plane(int(state.plane));add_child(visual);planes[id]=visual
 var node: Node3D=planes[id]
 node.position=state.p;node.rotation=Vector3(state.pitch,state.yaw,state.roll)
 node.visible=not bool(state.crashed)
 node.update_state(state)
 node.spin_speed=20.0+minf(state.v.length()*2,90.0)
func update_session(session: Node, delta: float) -> void:
 if not session.joined or session.local_state.is_empty():
  for node: Node3D in planes.values():node.queue_free()
  planes.clear();camera_ready=false;cockpit_shell.deactivate()
  for ring: MeshInstance3D in checkpoint_nodes:ring.visible=false
  return
 var mine: int=session.multiplayer.get_unique_id()
 var visual_state: Dictionary=session.local_state.duplicate();visual_state.p+=session.visual_offset
 update_plane(mine,visual_state)
 var active: Array[int]=[mine]
 for id: int in session.others:
  update_plane(id,session.remote_state(id));active.append(id)
 for id: int in planes.keys():
  if not id in active:planes[id].queue_free();planes.erase(id)
 planes[mine].visible=not bool(visual_state.crashed) and camera_mode not in [CameraMode.FORWARD,CameraMode.COCKPIT]
 instrument_throttle=float(session.controls.throttle)
 update_camera(visual_state,delta)
 for ring: MeshInstance3D in checkpoint_nodes:ring.visible=session.mode=="race"

func set_camera_mode(value: int) -> void:
 camera_mode=clampi(value,CameraMode.CHASE,CameraMode.COCKPIT)
 camera_ready=false;orbit=0;look_pitch=0;camera_zoom=1
 if cockpit_shell:cockpit_shell.deactivate()
 camera_mode_changed.emit()
func cycle_camera() -> void:set_camera_mode((camera_mode+1)%4)
func camera_caption(lang: String) -> String:
 return (["Chase","Forward","Orbit","Cockpit"] if lang=="en" else ["Сзади","Вперёд","Обзор","Кабина"])[camera_mode]
func update_camera(s: Dictionary,delta: float) -> void:
 var basis: Basis=Basis.from_euler(Vector3(0,s.yaw+orbit,0))
 var chase: float=maxf(22.0,float(AviaFlight.PLANES[int(s.plane)].geometry.length_m)*1.6)
 var destination: Vector3=s.p+basis*Vector3(0,chase*.27,chase)
 var target: Vector3=s.p+Vector3.UP*1.8
 var internal: bool=camera_mode in [CameraMode.FORWARD,CameraMode.COCKPIT]
 var aircraft_basis: Basis=Basis.from_euler(Vector3(s.pitch,s.yaw,s.roll))
 if camera_mode==CameraMode.ORBIT:
  destination=s.p+Basis.from_euler(Vector3(-.27-look_pitch,s.yaw+orbit,0))*Vector3(0,0,chase*camera_zoom)
 if internal:destination=s.p+aircraft_basis*Vector3(0,1.6,-float(AviaFlight.PLANES[int(s.plane)].geometry.length_m)*.15)
 if not camera_ready:camera_offset=destination-s.p;camera_ready=true
 # Smooth the relative chase vector; world-position lag grew with jet speed and hid the aircraft.
 camera_offset=camera_offset.lerp(destination-s.p,1.0 if internal else 1.0-exp(-delta*(8.0 if reduced_motion else 4.0)))
 camera.position=s.p+camera_offset
 if internal:camera.basis=aircraft_basis*Basis.from_euler(Vector3(look_pitch,orbit,0))
 elif camera.position.distance_to(target)>0.01:camera.look_at(target)
 camera.near=.08 if internal else .5
 if cockpit and not bool(s.crashed):
  cockpit_shell.transform=Transform3D(aircraft_basis,destination)
  cockpit_shell.show();cockpit_shell.update_instruments(s,delta,instrument_speed_unit,instrument_altitude_unit,language,instrument_throttle)
 else:cockpit_shell.deactivate()
 camera.fov=70.0 if reduced_motion else lerpf(camera.fov,70.0+minf(s.v.length()*0.06,7.0),delta*2)

func prepare_aircraft(index: int) -> void:
 # Compile/upload the selected model's material variants before admission deadlines.
 var warm: AviaAircraft=AviaAircraft.build(clampi(index,0,AviaFlight.PLANES.size()-1));add_child(warm)
 warm.position=camera.position-camera.global_basis.z*32.0
 if warm.exhaust:warm.exhaust.show()
 await RenderingServer.frame_post_draw
 warm.queue_free()
