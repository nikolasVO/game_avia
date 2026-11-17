class_name AviaAircraft
extends Node3D
## Original aircraft and imported fighter candidates with authored moving assemblies.
var landing_gear: Node3D
var gear_legs: Array[Node3D]=[]
var gear_axes: Array[Vector3]=[]
var gear_instances: MultiMeshInstance3D
var gear_deployment: float=1.0
var gear_target: float=1.0
var gear_duration: float=1.1
var systems_initialized: bool=false
var exhaust: Node3D
var vectoring_nozzles: Array[Node3D]=[]
var sweep_wings: Array[Node3D]=[]
var sweep_sides: Array[float]=[]
var sweep_fraction: float=0.0
var sweep_target: float=0.0
var sweep_initialized: bool=false
var propeller: Node3D
var spin_speed: float=30.0
var airframe_source: String="procedural flight prototype"
static var _shared_vertex_material: StandardMaterial3D
static func _face(st: SurfaceTool, vertices: Array[Vector3], color: Color, outward: Vector3) -> void:
 var normal: Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
 if normal.dot(outward)<0:vertices.reverse();normal=-normal
 for i: int in range(1,vertices.size()-1):
  for vertex: Vector3 in [vertices[0],vertices[i],vertices[i+1]]:
   st.set_normal(normal);st.set_color(color);st.add_vertex(vertex)
static func _solid(st: SurfaceTool, v: Array[Vector3], color: Color) -> void:
 var center: Vector3=Vector3.ZERO
 for p: Vector3 in v:center+=p/float(v.size())
 for ids: Array in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
  var face: Array[Vector3]=[];var midpoint: Vector3=Vector3.ZERO
  for id: int in ids:face.append(v[id]);midpoint+=v[id]/4.0
  _face(st,face,color,midpoint-center)
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
 var v: Array[Vector3]=[]
 for p: Vector3 in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,-1,1),Vector3(-1,-1,1),Vector3(-1,1,-1),Vector3(1,1,-1),Vector3(1,1,1),Vector3(-1,1,1)]:v.append(center+p*size*0.5)
 _solid(st,v,color)
static func _loft(st: SurfaceTool, sections: Array[Vector3], offset_y: float, color: Color, sides: int, offset_x: float=0.0) -> void:
 # Sections: z, half-width, half-height. Separate from the shared flight parameters.
 var rings: Array=[]
 for section: Vector3 in sections:
  var ring: Array[Vector3]=[]
  for i: int in range(sides):
   var angle: float=TAU*i/sides
   ring.append(Vector3(offset_x+cos(angle)*section.y,offset_y+sin(angle)*section.z,section.x))
  rings.append(ring)
 _face(st,rings[0].duplicate(),color,Vector3.FORWARD)
 _face(st,rings[-1].duplicate(),color,Vector3.BACK)
 for j: int in range(1,rings.size()):
  for i: int in range(sides):
   var next: int=(i+1)%sides
   var a: Vector3=rings[j-1][i];var b: Vector3=rings[j][i];var c: Vector3=rings[j][next];var d: Vector3=rings[j-1][next]
   _face(st,[a,b,c,d],color,Vector3(a.x-offset_x,(a.y-offset_y),0))
static func _wing(st: SurfaceTool, span: float, chord: float, z: float, y: float, sweep: float, color: Color) -> void:
 for side: float in [-1.0,1.0]:
  var tip: float=span*side;var rise: float=span*0.045
  _solid(st,[Vector3(0,y-0.09,z-chord/2),Vector3(tip,y+rise-0.05,z+sweep-chord*0.23),Vector3(tip,y+rise-0.05,z+sweep+chord*0.23),Vector3(0,y-0.09,z+chord/2),Vector3(0,y+0.09,z-chord/2),Vector3(tip,y+rise+0.05,z+sweep-chord*0.23),Vector3(tip,y+rise+0.05,z+sweep+chord*0.23),Vector3(0,y+0.09,z+chord/2)],color)
static func _mesh(st: SurfaceTool, parent: Node3D, name_: String, near: float, far: float) -> MeshInstance3D:
 var node: MeshInstance3D=MeshInstance3D.new();node.name=name_;node.mesh=st.commit()
 if _shared_vertex_material==null:
  _shared_vertex_material=StandardMaterial3D.new();_shared_vertex_material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX;_shared_vertex_material.vertex_color_use_as_albedo=true;_shared_vertex_material.roughness=0.82;_shared_vertex_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 node.material_override=_shared_vertex_material;node.visibility_range_begin=near;node.visibility_range_end=far;parent.add_child(node)
 return node
static func build(index: int) -> AviaAircraft:
 if index>=3:return AviaFighterVisual.create(index)
 var root: AviaAircraft=AviaAircraft.new()
 var color: Color=AviaFlight.PLANES[index].color;var cream: Color=Color("e6dfc4");var dark: Color=Color("334c58")
 for distant: bool in [false,true]:
  var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var sides: int=4 if distant else 8
  _loft(st,[Vector3(-4.5,0.16,0.2),Vector3(-3.3,0.72,0.7),Vector3(-0.8,0.95,0.85),Vector3(1.4,0.65,0.65),Vector3(4.3,0.12,0.28)],0,color,sides)
  _wing(st,6.3 if index==0 else 5.5 if index==1 else 4.5,2.1,0.15,0.7 if index==0 else -0.35,0.2 if index==0 else 0.7 if index==1 else 2.0,color)
  _wing(st,2.5 if index!=2 else 2.1,1.1,3.35,0.25,0.5,cream)
  _solid(st,[Vector3(-0.09,0.3,2.6),Vector3(0.09,0.3,2.6),Vector3(0.09,0.3,4.3),Vector3(-0.09,0.3,4.3),Vector3(-0.09,2.15,3.55),Vector3(0.09,2.15,3.55),Vector3(0.09,1.4,4.3),Vector3(-0.09,1.4,4.3)],color)
  if not distant:
   _loft(st,[Vector3(-2.3,0.15,0.12),Vector3(-1.25,0.65,0.55),Vector3(0.5,0.5,0.35),Vector3(1.1,0.1,0.05)],0.72,dark,6)
   _box(st,Vector3(0,-0.52,-1.1),Vector3(1.55,0.08,2.8),cream)
   for x: float in [-1.4,1.4]:
    _box(st,Vector3(x,-0.85,0.65),Vector3(0.12,0.85,0.14),dark)
    _box(st,Vector3(x,-1.2,0.65),Vector3(0.35,0.48,0.65),dark)
   _box(st,Vector3(0,-1.05,3.4),Vector3(0.2,0.4,0.4),dark)
   if index==2:
    for x: float in [-0.8,0.8]:_box(st,Vector3(x,-0.15,1.0),Vector3(0.45,0.55,1.6),dark)
    _loft(st,[Vector3(3.3,0.38,0.38),Vector3(4.5,0.3,0.3)],-0.1,dark,8)
  _mesh(st,root,"Distant" if distant else "Airframe",800 if distant else 0,4500 if distant else 800)
 if index!=2:
  root.propeller=Node3D.new();root.propeller.name="Propeller";root.propeller.position.z=-4.65;root.add_child(root.propeller)
  var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  _box(st,Vector3.ZERO,Vector3(0.16,2.5,0.12),dark);_box(st,Vector3.ZERO,Vector3(2.5,0.16,0.12),dark)
  _mesh(st,root.propeller,"Blades",0,800)
 return root
func _process(delta: float) -> void:
 if propeller and visible:propeller.rotate_z(spin_speed*delta)
 advance_gear(delta)
 if sweep_initialized:pose_sweep(move_toward(sweep_fraction,sweep_target,maxf(delta,0.0)/2.5))

func update_state(state: Dictionary) -> void:
 if not sweep_wings.is_empty():
  # Reference/prototype animation only. Planned swing-wing types remain unavailable.
  var sweep: float=clampf(((state.v as Vector3).length()-180.0)/150.0,0,1)
  if bool(state.get("gear",false)) or bool(state.get("flaps",false)):sweep=0.0
  sweep_target=sweep
  if not sweep_initialized:pose_sweep(sweep);sweep_initialized=true
 if landing_gear:
  gear_target=1.0 if bool(state.get("gear",true)) else 0.0
  # First snapshot establishes a baseline; later authoritative changes animate.
  if not systems_initialized:
   gear_deployment=gear_target;systems_initialized=true;_pose_gear()
 if exhaust:exhaust.visible=bool(state.get("afterburner",false)) and not state.crashed
 for nozzle: Node3D in vectoring_nozzles:
  # Cosmetic cue for the existing simplified low-speed thrust-vectoring forces.
  # Server-approved velocity/angular state drives it; this adds no simulation force.
  var authority: float=clampf(1.0-(state.v as Vector3).length()/100.0,0,1)
  var rates: Vector3=state.get("rates",Vector3.ZERO)
  nozzle.rotation.x=clampf(-rates.x*0.18,-0.22,0.22)*authority
  nozzle.rotation.y=clampf(-rates.y*0.18,-0.16,0.16)*authority

func pose_sweep(fraction: float) -> void:
 sweep_fraction=clampf(fraction,0,1)
 for i: int in sweep_wings.size():sweep_wings[i].rotation.y=-sweep_sides[i]*deg_to_rad(48.0)*sweep_fraction

func advance_gear(delta: float) -> void:
 if not landing_gear or not systems_initialized:return
 # Constant travel time remains independent of frame rate and snapshot frequency.
 var previous: float=gear_deployment
 gear_deployment=move_toward(previous,gear_target,maxf(0.0,delta)/gear_duration)
 if gear_deployment==previous:return
 _pose_gear()

func _pose_gear() -> void:
 landing_gear.visible=gear_deployment>0.001
 for i: int in gear_legs.size():
  gear_legs[i].rotation=gear_axes[i]*(1.0-gear_deployment)*1.48
  if gear_instances:gear_instances.multimesh.set_instance_transform(i,gear_legs[i].transform)
