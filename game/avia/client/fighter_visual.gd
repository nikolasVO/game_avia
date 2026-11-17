class_name AviaFighterVisual
extends RefCounted
## Candidate imported body or authored procedural body; flight remains independent.
static func create(index: int) -> AviaAircraft:
 var spec: Dictionary=AviaFlight.PLANES[index];var g: Dictionary=spec.geometry
 var root: AviaAircraft=AviaAircraft.new()
 var color: Color=spec.color;var dark: Color=Color("293f49");var glass: Color=Color("78b5c3")
 var length: float=float(g.length_m);var span: float=float(g.span_m);var twin: bool=int(g.engines)==2
 var delta: bool=str(g.planform).contains("delta");var canard: bool=str(g.planform).contains("canard")
 var imported: bool=spec.has("visual") and ResourceLoader.exists(str(spec.visual.scene))
 if imported:
  var body: Node3D=AviaCatalogProp.build(load(str(spec.visual.scene)) as PackedScene)
  body.name="AIModel";body.position.y=float(spec.visual.offset_y_m);root.add_child(body)
  root.airframe_source="AI candidate with procedural landing gear/effects; production QA pending"
 for lod: int in (0 if imported else 3):
  var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var sides: int=8 if lod==0 else 6 if lod==1 else 4
  AviaAircraft._loft(st,[Vector3(-length*.51,.04,.06),Vector3(-length*.3,.48,.55),Vector3(-length*.12,.8 if twin else .6,.65),Vector3(length*.17,.78 if twin else .55,.55),Vector3(length*.44,.45,.35)],0.1,color,sides)
  # Cropped swept wing or canard delta; source geometry is authored independently.
  AviaAircraft._wing(st,span*.5,length*(.36 if delta else .23),length*.02,-.1,length*(.22 if delta else .13),color)
  if not delta:AviaAircraft._wing(st,span*.24,length*.13,length*.34,.12,length*.08,color.darkened(.06))
  if canard:AviaAircraft._wing(st,span*.22,length*.10,-length*.21,.2,length*.04,color.lightened(.05))
  var fins: Array=[-1.0,1.0] if twin and not delta else [0.0]
  for side: float in fins:
   var x: float=side*length*.08
   AviaAircraft._solid(st,[Vector3(x-.07,.25,length*.23),Vector3(x+.07,.25,length*.23),Vector3(x+.07,.25,length*.44),Vector3(x-.07,.25,length*.44),Vector3(x-.07,length*.16,length*.34),Vector3(x+.07,length*.16,length*.34),Vector3(x+.07,length*.11,length*.44),Vector3(x-.07,length*.11,length*.44)],color)
  if lod<2:
   # F-16 chin intake versus separated paired intakes and engines on Su/F-15.
   for side: float in ([-1.0,1.0] if twin else [0.0]):
    var intake_x: float=side*length*.055
    AviaAircraft._box(st,Vector3(intake_x,-.40,-length*.08),Vector3(.75,.65,length*.16),dark)
    var nozzle: SurfaceTool=SurfaceTool.new();nozzle.begin(Mesh.PRIMITIVE_TRIANGLES)
    AviaAircraft._loft(nozzle,[Vector3(length*.29,.48,.42),Vector3(length*.46,.40,.36)],-.1,dark,sides)
    var mesh: MeshInstance3D=AviaAircraft._mesh(nozzle,root,"Nozzle%d_%s" % [lod,str(side)],0 if lod==0 else 250,250 if lod==0 else 800);mesh.position.x=intake_x
   AviaAircraft._loft(st,[Vector3(-length*.30,.03,.05),Vector3(-length*.22,.42,.60),Vector3(-length*.10,.4,.50),Vector3(-length*.02,.04,.05)],.65,glass,sides)
  AviaAircraft._mesh(st,root,"Airframe" if lod==0 else "LOD1" if lod==1 else "Distant",[0,250,800][lod],[250,800,4500][lod])
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
  exhaust.position.x=side*length*.055
 root.exhaust.hide()
 return root
