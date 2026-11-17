class_name AviaFighterVisual
extends RefCounted
## Candidate imported body or authored procedural body; flight remains independent.
static func create(index: int, use_imported: bool=true) -> AviaAircraft:
 var spec: Dictionary=AviaFlight.PLANES[index];var g: Dictionary=spec.geometry
 var root: AviaAircraft=AviaAircraft.new()
 var color: Color=spec.color;var dark: Color=Color("293f49");var glass: Color=Color("78b5c3")
 var length: float=float(g.length_m);var span: float=float(g.span_m);var twin: bool=int(g.engines)==2
 var width: float=float(g.get("body_half_width_m",.8));var height: float=float(g.get("body_half_height_m",.65))
 var delta: bool=str(g.planform).contains("delta");var canard: bool=str(g.planform).contains("canard")
 var imported: bool=use_imported and spec.has("visual") and ResourceLoader.exists(str(spec.visual.scene))
 if imported:
  var body: Node3D=AviaCatalogProp.build(load(str(spec.visual.scene)) as PackedScene)
  body.name="AIModel";body.position.y=float(spec.visual.offset_y_m);root.add_child(body)
  root.airframe_source="AI candidate with procedural landing gear/effects; production QA pending"
 for lod: int in (0 if imported else 3):
  var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var sides: int=8 if lod==0 else 6 if lod==1 else 4
  AviaAircraft._loft(st,[Vector3(-length*.51,.04,.06),Vector3(-length*.3,width*.55,height*.9),Vector3(-length*.12,width,height),Vector3(length*.17,width*1.1,height*.9),Vector3(length*.44,width*.65,height*.55)],0.1,color,sides)
  # Cropped swept wing or canard delta; source geometry is authored independently.
  AviaAircraft._wing(st,span*.5,float(g.get("wing_root_chord_m",length*(.36 if delta else .23))),length*.02,-.1,float(g.get("wing_sweep_m",length*(.22 if delta else .13))),color)
  if g.has("lerx_half_span_m") and not delta:AviaAircraft._wing(st,float(g.lerx_half_span_m),float(g.lerx_chord_m),float(g.lerx_z_m),-.02,0.6,color)
  if not delta:AviaAircraft._wing(st,span*.24,length*.13,length*.34,.12,length*.08,color.darkened(.06))
  if canard:AviaAircraft._wing(st,span*.22,length*.10,-length*.21,.2,length*.04,color.lightened(.05))
  var fins: Array=[-1.0,1.0] if twin and not delta else [0.0]
  for side: float in fins:
   var x: float=side*length*.08
   var fin_height: float=float(g.get("fin_height_m",length*.16));var tip_x: float=x+side*tan(deg_to_rad(float(g.get("fin_cant_degrees",0))))*fin_height
   AviaAircraft._solid(st,[Vector3(x-.07,.25,length*.23),Vector3(x+.07,.25,length*.23),Vector3(x+.07,.25,length*.44),Vector3(x-.07,.25,length*.44),Vector3(tip_x-.07,fin_height,length*.34),Vector3(tip_x+.07,fin_height,length*.34),Vector3(tip_x+.07,fin_height*.7,length*.44),Vector3(tip_x-.07,fin_height*.7,length*.44)],color)
  if lod<2:
   # Intake count and engine count differ: Gripen has side intakes and one nozzle.
   var intake_sides: Array=[-1.0,1.0] if str(g.get("intake_layout","side_pair" if twin else "chin_single"))=="side_pair" else [0.0]
   for side: float in intake_sides:
    var x: float=side*maxf(width,float(g.get("engine_spacing_m",length*.11))*.5)
    AviaAircraft._box(st,Vector3(x,-.35,-length*.08),Vector3(.75,.65,length*.16),dark)
   for side: float in ([-1.0,1.0] if twin else [0.0]):
    var intake_x: float=side*float(g.get("engine_spacing_m",length*.11))*.5
    if twin and float(g.get("engine_channel_length_m",0))>0:
     AviaAircraft._loft(st,[Vector3(length*.46-float(g.engine_channel_length_m),.45,.40),Vector3(length*.25,.56,.48),Vector3(length*.44,.43,.38)],-.15,color.darkened(.06),sides,intake_x)
    AviaAircraft._loft(st,[Vector3(length*.29,.48,.42),Vector3(length*.46,.40,.36)],-.1,dark,sides,intake_x)
   AviaAircraft._loft(st,[Vector3(-length*.30,.03,.05),Vector3(-length*.22,.42,.60),Vector3(-length*.10,.4,.50),Vector3(-length*.02,.04,.05)],.65,glass,sides)
  AviaAircraft._mesh(st,root,"Airframe" if lod==0 else "LOD1" if lod==1 else "Distant",[0,250,800][lod],[250,800,4500][lod])
 if imported and bool(spec.visual.get("nozzle_repair",false)):
  # Explicitly labelled authored repair: the AI candidate lacks clear engine exits.
  for side: float in ([-1.0,1.0] if twin else [0.0]):
   var nozzle: Node3D=Node3D.new();nozzle.name="RepairedNozzle"+str(side)
   nozzle.position=Vector3(side*float(g.get("engine_spacing_m",length*.11))*.5,-.15,length*.44);root.add_child(nozzle)
   var tube: SurfaceTool=SurfaceTool.new();tube.begin(Mesh.PRIMITIVE_TRIANGLES)
   for segment: int in 8:
    var a: float=TAU*segment/8.0;var b: float=TAU*(segment+1)/8.0
    var radial: Vector3=Vector3(cos((a+b)*.5),sin((a+b)*.5),0)
    var outer_a: Vector3=Vector3(cos(a)*.46,sin(a)*.46,0);var outer_b: Vector3=Vector3(cos(b)*.46,sin(b)*.46,0)
    var inner_a: Vector3=Vector3(cos(a)*.34,sin(a)*.34,0);var inner_b: Vector3=Vector3(cos(b)*.34,sin(b)*.34,0)
    var depth: Vector3=Vector3(0,0,length*.06+.35)
    AviaAircraft._face(tube,[outer_a,outer_b,outer_b+depth,outer_a+depth],dark,radial)
    AviaAircraft._face(tube,[inner_b,inner_a,inner_a+depth,inner_b+depth],Color("11222a"),-radial)
    AviaAircraft._face(tube,[outer_a+depth,outer_b+depth,inner_b+depth,inner_a+depth],Color("687c83"),Vector3.BACK)
   AviaAircraft._mesh(tube,nozzle,"Nozzle",0,800)
   if bool(spec.systems.get("thrust_vectoring",false)):root.vectoring_nozzles.append(nozzle)
  root.airframe_source="AI candidate body with procedural nozzle repair, landing gear/effects; production QA pending"
 root.landing_gear=Node3D.new();root.landing_gear.name="LandingGear";root.add_child(root.landing_gear)
 var gear: SurfaceTool=SurfaceTool.new();gear.begin(Mesh.PRIMITIVE_TRIANGLES)
 for location: Vector3 in [Vector3(0,-.8,-length*.25),Vector3(-length*.09,-.8,length*.07),Vector3(length*.09,-.8,length*.07)]:
  AviaAircraft._box(gear,location,Vector3(.12,.85,.14),color)
  AviaAircraft._box(gear,location+Vector3(0,-.42,0),Vector3(.25,.35,.5),dark)
 AviaAircraft._mesh(gear,root.landing_gear,"Gear",0,500)
 root.exhaust=Node3D.new();root.exhaust.name="Afterburner";root.add_child(root.exhaust)
 for side: float in ([-1.0,1.0] if twin else [0.0]):
  # Reuse the airframe's vertex-lit material path; no additional unshaded variant.
  var flame: SurfaceTool=SurfaceTool.new();flame.begin(Mesh.PRIMITIVE_TRIANGLES)
  AviaAircraft._loft(flame,[Vector3(length*.46,.27,.27),Vector3(length*.46+1.9,.04,.04)],-.1,Color("f7b564"),6)
  var exhaust: MeshInstance3D=AviaAircraft._mesh(flame,root.exhaust,"Flame"+str(side),0,800)
  exhaust.position.x=side*float(g.get("engine_spacing_m",length*.11))*.5
 root.exhaust.hide()
 return root
