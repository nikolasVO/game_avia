extends Node3D
var planes: Dictionary={}
var checkpoint_nodes: Array[MeshInstance3D]=[]
var camera: Camera3D
var camera_ready: bool=false
var cockpit: bool=false
var reduced_motion: bool=false
var orbit: float=0.0
func material(color: Color) -> StandardMaterial3D:
 var m: StandardMaterial3D=StandardMaterial3D.new()
 m.albedo_color=color;m.roughness=0.85
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
   for v: Vector3 in [a,b,c,b,d,c]:
    v.y=AviaFlight.height(v)-0.05
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
 for p: Vector3 in AviaRules.CHECKPOINTS:
  var ring: MeshInstance3D=MeshInstance3D.new();var torus: TorusMesh=TorusMesh.new()
  torus.inner_radius=AviaRules.RADIUS-2;torus.outer_radius=AviaRules.RADIUS;torus.rings=24;torus.ring_segments=8
  ring.mesh=torus;ring.position=p;ring.rotation.x=PI/2;ring.material_override=material(Color("edc777"));add_child(ring);checkpoint_nodes.append(ring)
 camera=Camera3D.new();camera.far=6500;camera.current=true;add_child(camera)
 camera.position=Vector3(90,70,270);camera.look_at(Vector3(0,15,-200))
func make_plane(index: int) -> Node3D:
 var root: Node3D=Node3D.new()
 var color: Color=AviaFlight.PLANES[index].color
 box(root,Vector3(0,0,0),Vector3(1.8,1.7,8.8),color)
 var wing: MeshInstance3D=box(root,Vector3(0,0,0.4),Vector3(12.5 if index!=2 else 8.8,0.25,2.0),color)
 wing.rotation.z=0.025
 box(root,Vector3(0,0.2,3.5),Vector3(5.2,0.18,1.1),color)
 box(root,Vector3(0,1.0,3.6),Vector3(0.2,2.4,1.8),color.darkened(0.1))
 box(root,Vector3(0,1.0,-1.5),Vector3(1.4,0.65,2.6),Color("365563"))
 if index!=2:box(root,Vector3(0,0,-4.6),Vector3(0.16,3.6,0.16),Color("d5d0b5"))
 for x: float in [-1.4,1.4]:box(root,Vector3(x,-1.0,0.5),Vector3(0.5,0.75,0.8),Color("34444b"))
 box(root,Vector3(0,-0.9,3.3),Vector3(0.3,0.6,0.55),Color("34444b"))
 return root
func update_plane(id: int, state: Dictionary) -> void:
 if not planes.has(id):
  var visual: Node3D=make_plane(int(state.plane));add_child(visual);planes[id]=visual
 var node: Node3D=planes[id]
 node.position=state.p;node.rotation=Vector3(state.pitch,state.yaw,state.roll)
 node.visible=not bool(state.crashed)
 if id!=multiplayer.get_unique_id():
  var engine: AudioStreamPlayer3D=node.get_node_or_null("Engine")
  if not engine:
   engine=AudioStreamPlayer3D.new();engine.name="Engine";engine.stream=AviaSound.engine_stream();engine.unit_size=24;engine.max_distance=700;node.add_child(engine);engine.play()
  engine.volume_db=-70 if state.crashed else -25
  engine.pitch_scale=0.8+minf(state.v.length()/80.0,1.5)
func update_session(session: Node, delta: float) -> void:
 if not session.joined or session.local_state.is_empty():
  for node: Node3D in planes.values():node.queue_free()
  planes.clear();camera_ready=false
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
 var s: Dictionary=visual_state
 var basis: Basis=Basis.from_euler(Vector3(0,s.yaw+orbit,0))
 var destination: Vector3=s.p+basis*Vector3(0,6,22)
 var target: Vector3=s.p+Vector3.UP*1.8
 if cockpit:
  destination=s.p+Vector3.UP*2-Basis.from_euler(Vector3(s.pitch,s.yaw,s.roll)).z*2
  target=destination-Basis.from_euler(Vector3(s.pitch,s.yaw,s.roll)).z*200
 if not camera_ready:camera.position=destination;camera_ready=true
 camera.position=camera.position.lerp(destination,1.0 if cockpit else 1.0-exp(-delta*(8.0 if reduced_motion else 4.0)))
 if camera.position.distance_to(target)>0.01:camera.look_at(target)
 camera.fov=70.0 if reduced_motion else lerpf(camera.fov,70.0+minf(s.v.length()*0.06,7.0),delta*2)
 for ring: MeshInstance3D in checkpoint_nodes:ring.visible=session.mode=="race"
