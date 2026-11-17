class_name AviaFighterVisual
extends RefCounted
## Candidate imported body or authored procedural body; flight remains independent.
static func create(index: int, use_imported: bool=true) -> AviaAircraft:
 return create_spec(AviaFlight.PLANES[index],use_imported)
static func create_spec(spec: Dictionary, use_imported: bool=false) -> AviaAircraft:
 # Planned references never need to enter the playable catalog.
 var g: Dictionary=spec.geometry
 var root: AviaAircraft=AviaAircraft.new()
 root.sweep_spec=spec
 var color: Color=spec.color if spec.color is Color else Color(str(spec.color));var dark: Color=Color("293f49");var glass: Color=Color("78b5c3")
 var length: float=float(g.length_m);var span: float=float(g.span_m);var twin: bool=int(g.engines)==2
 var width: float=float(g.get("body_half_width_m",.8));var height: float=float(g.get("body_half_height_m",.65))
 var delta: bool=str(g.planform).contains("delta");var canard: bool=str(g.planform).contains("canard")
 var imported: bool=use_imported and spec.has("visual") and ResourceLoader.exists(str(spec.visual.scene))
 if imported:
  var body: Node3D
  if spec.visual.has("articulated_lods"):
   body=Node3D.new()
   for path: String in spec.visual.articulated_lods:
    var tier: Node3D=AviaCatalogProp.build(load(path) as PackedScene);body.add_child(tier)
    for panel: Node in tier.find_children("*Wing*","MeshInstance3D",true,false):
     root.sweep_wings.append(panel);root.sweep_sides.append(-1.0 if str(panel.name).contains("Left") else 1.0)
  else:body=AviaCatalogProp.build(load(str(spec.visual.scene)) as PackedScene)
  body.name="AIModel";body.position.y=float(spec.visual.offset_y_m);root.add_child(body)
  root.airframe_source="AI candidate with procedural landing gear/effects; production QA pending"
  if spec.visual.has("articulated_lods"):
   # Authored glove covers the cut pivot seam throughout travel, never a static wing.
   for lod: int in 3:
    var glove: SurfaceTool=SurfaceTool.new();glove.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side: float in [-1.0,1.0]:
     var center: Vector3=Vector3(side*float(g.sweep_pivot_x_m),-.08,float(g.sweep_pivot_z_m))
     for segment: int in 12:
      var a: float=TAU*segment/12.0;var b: float=TAU*(segment+1)/12.0
      var pa: Vector3=Vector3(cos(a)*1.1,0,sin(a)*2.35);var pb: Vector3=Vector3(cos(b)*1.1,0,sin(b)*2.35)
      AviaAircraft._face(glove,[center+Vector3(0,.10,0),center+pa+Vector3(0,.10,0),center+pb+Vector3(0,.10,0)],color,Vector3.UP)
      AviaAircraft._face(glove,[center-Vector3(0,.10,0),center+pb-Vector3(0,.10,0),center+pa-Vector3(0,.10,0)],color,Vector3.DOWN)
      AviaAircraft._face(glove,[center+pa-Vector3(0,.10,0),center+pb-Vector3(0,.10,0),center+pb+Vector3(0,.10,0),center+pa+Vector3(0,.10,0)],color,Vector3(cos(a),0,sin(a)))
    AviaAircraft._mesh(glove,root,"PivotGloveLOD"+str(lod),[0,350,900][lod],[350,900,2500][lod])
   root.airframe_source="Articulated AI candidate with authored pivot gloves/gear/effects; production QA pending"
 for lod: int in (0 if imported else 3):
  var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var sides: int=8 if lod==0 else 6 if lod==1 else 4
  if g.has("box_body_sections_m"):_box_body(st,g.box_body_sections_m,color)
  elif g.has("body_sections_m"):
   var body_sections: Array[Vector3]=[]
   for section: Array in g.body_sections_m:body_sections.append(Vector3(float(section[0]),float(section[1]),float(section[2])))
   AviaAircraft._loft(st,body_sections,0,color,sides)
  else:AviaAircraft._loft(st,[Vector3(-length*.51,.04,.06),Vector3(-length*.3,width*.55,height*.9),Vector3(-length*.12,width,height),Vector3(length*.17,width*1.1,height*.9),Vector3(length*.44,width*.65,height*.55)],0.1,color,sides)
  # Cropped swept wing or canard delta; source geometry is authored independently.
  if bool(spec.systems.get("variable_sweep",false)):
   # Fixed glove; articulated panels are separate from every body LOD.
   if g.has("glove_outline_m"):_surface_pair(st,g.glove_outline_m,-.1,.16,color)
   else:AviaAircraft._wing(st,float(g.get("glove_half_span_m",span*.18)),length*.31,-.35,-.1,.9,color)
  elif g.has("wing_outline_m"):
   _surface_pair(st,g.wing_outline_m,float(g.get("wing_y_m",-.1)),.16,color,float(g.get("wing_dihedral_degrees",0)))
  else:
   AviaAircraft._wing(st,span*.5,float(g.get("wing_root_chord_m",length*(.36 if delta else .23))),length*.02,-.1,float(g.get("wing_sweep_m",length*(.22 if delta else .13))),color)
  if g.has("lerx_outline_m"):_surface_pair(st,g.lerx_outline_m,-.02,.14,color)
  if g.has("lerx_half_span_m") and not delta:AviaAircraft._wing(st,float(g.lerx_half_span_m),float(g.lerx_chord_m),float(g.lerx_z_m),-.02,0.6,color)
  if g.has("stabilizer_outline_m"):_surface_pair(st,g.stabilizer_outline_m,.12,.12,color.darkened(.06))
  elif not delta:AviaAircraft._wing(st,span*.24,length*.13,length*.34,.12,length*.08,color.darkened(.06))
  if canard:AviaAircraft._wing(st,span*.22,length*.10,-length*.21,.2,length*.04,color.lightened(.05))
  var fins: Array=[-1.0,1.0] if int(g.get("fin_count",2 if twin and not delta else 1))==2 else [0.0]
  for side: float in fins:
   var x: float=side*float(g.get("fin_half_spacing_m",length*.08))
   var fin_height: float=float(g.get("fin_height_m",length*.16));var tip_x: float=x+side*tan(deg_to_rad(float(g.get("fin_cant_degrees",0))))*fin_height
   if g.has("fin_outline_m"):_fin(st,g.fin_outline_m,x,side,float(g.get("fin_cant_degrees",0)),color)
   else:AviaAircraft._solid(st,[Vector3(x-.07,.25,length*.23),Vector3(x+.07,.25,length*.23),Vector3(x+.07,.25,length*.44),Vector3(x-.07,.25,length*.44),Vector3(tip_x-.07,fin_height,length*.34),Vector3(tip_x+.07,fin_height,length*.34),Vector3(tip_x+.07,fin_height*.7,length*.44),Vector3(tip_x-.07,fin_height*.7,length*.44)],color)
  if str(g.get("intake_layout",""))=="nose_ring":_nose_intake(st,g.nose_intake,color,sides)
  if lod<2:
   # Intake count and engine count differ: Gripen has side intakes and one nozzle.
   var layout: String=str(g.get("intake_layout","side_pair" if twin else "chin_single"))
   var intake_sides: Array=[] if layout=="nose_ring" else [-1.0,1.0] if layout=="side_pair" else [0.0]
   for side: float in intake_sides:
    var x: float=side*maxf(width,float(g.get("engine_spacing_m",length*.11))*.5)
    var intake_size: Array=g.get("intake_size_m",[.75,.65,length*.16])
    AviaAircraft._box(st,Vector3(x,-.35,float(g.get("intake_z_m",-length*.08))),Vector3(float(intake_size[0]),float(intake_size[1]),float(intake_size[2])),dark)
   for side: float in ([-1.0,1.0] if twin else [0.0]):
    var intake_x: float=side*float(g.get("engine_spacing_m",length*.11))*.5
    if twin and float(g.get("engine_channel_length_m",0))>0:
     AviaAircraft._loft(st,[Vector3(length*.46-float(g.engine_channel_length_m),.45,.40),Vector3(length*.25,.56,.48),Vector3(length*.44,.43,.38)],-.15,color.darkened(.06),sides,intake_x)
    AviaAircraft._loft(st,[Vector3(length*.29,.48,.42),Vector3(length*.46,.40,.36)],-.1,dark,sides,intake_x)
   var canopy: Array[Vector3]=[]
   for section: Array in g.get("canopy_sections_m",[[-length*.30,.03,.05],[-length*.22,.42,.60],[-length*.10,.4,.50],[-length*.02,.04,.05]]):canopy.append(Vector3(float(section[0]),float(section[1]),float(section[2])))
   AviaAircraft._loft(st,canopy,.65,glass,sides)
   if g.has("wingtip_rail_m"):
    var rail: Array=g.wingtip_rail_m
    for side: float in [-1.0,1.0]:AviaAircraft._box(st,Vector3(side*span*.5,float(rail[0]),float(rail[1])),Vector3(.12,.12,float(rail[2])),dark)
  AviaAircraft._mesh(st,root,"Airframe" if lod==0 else "LOD1" if lod==1 else "Distant",[0,250,800][lod],[250,800,4500][lod])
 if imported and bool(spec.visual.get("nozzle_repair",false)):
  # Explicitly labelled authored repair: the AI candidate lacks clear engine exits.
  for side: float in ([-1.0,1.0] if twin else [0.0]):
   var nozzle: Node3D=Node3D.new();nozzle.name="RepairedNozzle"+str(side)
   nozzle.position=Vector3(side*float(g.get("engine_spacing_m",length*.11))*.5,float(g.get("nozzle_center_y_m",-.15)),length*.44);root.add_child(nozzle)
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
   if bool(spec.visual.get("nozzle_inner_baffle",false)):
    # Optional authored dark cavity closes a defective generated exit without another body.
    for segment: int in 8:
     var a: float=TAU*segment/8.0;var b: float=TAU*(segment+1)/8.0
     var z: float=(length*.06+.35)*.8
     AviaAircraft._face(tube,[Vector3(0,0,z),Vector3(cos(a)*.34,sin(a)*.34,z),Vector3(cos(b)*.34,sin(b)*.34,z)],Color("11222a"),Vector3.BACK)
   AviaAircraft._mesh(tube,nozzle,"Nozzle",0,800)
   if bool(spec.systems.get("thrust_vectoring",false)):root.vectoring_nozzles.append(nozzle)
  root.airframe_source="AI candidate body with procedural nozzle repair, landing gear/effects; production QA pending"
 if not imported and bool(spec.systems.get("variable_sweep",false)):
  for side: float in [-1.0,1.0]:
   var pivot: Node3D=Node3D.new();pivot.name="SweepLeft" if side<0 else "SweepRight";pivot.position=Vector3(side*float(g.get("sweep_pivot_x_m",2.5)),-.1,float(g.get("sweep_pivot_z_m",-.3)));root.add_child(pivot)
   root.sweep_wings.append(pivot);root.sweep_sides.append(side)
   var reach: float=span*.5-absf(pivot.position.x)
   for lod: int in 3:
    var panel: SurfaceTool=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
    var x: float=side*reach;var aft: float=float(g.get("panel_sweep_m",2.6));var chord: float=float(g.get("panel_root_chord_m",4.5));var tip: float=float(g.get("panel_tip_chord_m",1.6))
    AviaAircraft._solid(panel,[Vector3(0,-.07,-chord*.5),Vector3(x,-.04,aft-tip*.5),Vector3(x,-.04,aft+tip*.5),Vector3(0,-.07,chord*.5),Vector3(0,.07,-chord*.5),Vector3(x,.04,aft-tip*.5),Vector3(x,.04,aft+tip*.5),Vector3(0,.07,chord*.5)],color)
    AviaAircraft._mesh(panel,pivot,"PanelLOD"+str(lod),[0,250,800][lod],[250,800,4500][lod])
 root.landing_gear=Node3D.new();root.landing_gear.name="LandingGear";root.add_child(root.landing_gear)
 root.gear_duration=clampf(float(spec.get("visual",{}).get("gear_retract_seconds",1.1)),0.5,2.0)
 var attachments: Array[Vector3]=[Vector3(0,-.375,-length*.25),Vector3(-length*.09,-.375,length*.07),Vector3(length*.09,-.375,length*.07)]
 for i: int in attachments.size():
  var leg: Node3D=Node3D.new();leg.name=["NoseLeg","LeftLeg","RightLeg"][i];leg.position=attachments[i];root.landing_gear.add_child(leg)
  root.gear_legs.append(leg);root.gear_axes.append([Vector3.LEFT,Vector3.BACK,Vector3.FORWARD][i])
 # Identical strut/wheel units use one instanced draw, not three extra surfaces.
 var gear: SurfaceTool=SurfaceTool.new();gear.begin(Mesh.PRIMITIVE_TRIANGLES)
 AviaAircraft._box(gear,Vector3(0,-.425,0),Vector3(.12,.85,.14),color)
 AviaAircraft._box(gear,Vector3(0,-.845,0),Vector3(.25,.35,.5),dark)
 var template: MeshInstance3D=AviaAircraft._mesh(gear,root.landing_gear,"GearTemplate",0,500)
 root.gear_instances=MultiMeshInstance3D.new();root.gear_instances.name="Gear"
 var instances: MultiMesh=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=template.mesh;instances.instance_count=3
 root.gear_instances.multimesh=instances;root.gear_instances.material_override=template.material_override;root.gear_instances.visibility_range_end=500;root.landing_gear.add_child(root.gear_instances);template.free()
 for i: int in root.gear_legs.size():instances.set_instance_transform(i,root.gear_legs[i].transform)
 root.exhaust=Node3D.new();root.exhaust.name="Afterburner";root.add_child(root.exhaust)
 for side: float in ([-1.0,1.0] if twin else [0.0]):
  # Reuse the airframe's vertex-lit material path; no additional unshaded variant.
  var flame: SurfaceTool=SurfaceTool.new();flame.begin(Mesh.PRIMITIVE_TRIANGLES)
  AviaAircraft._loft(flame,[Vector3(length*.46,.27,.27),Vector3(length*.46+1.9,.04,.04)],float(g.get("nozzle_center_y_m",-.1)),Color("f7b564"),6)
  var exhaust: MeshInstance3D=AviaAircraft._mesh(flame,root.exhaust,"Flame"+str(side),0,800)
  exhaust.position.x=side*float(g.get("engine_spacing_m",length*.11))*.5
 root.exhaust.hide()
 _build_airbrakes(root,spec,color)
 _build_flaps(root,spec,color)
 return root

static func _box_body(st: SurfaceTool,sections: Array,color: Color) -> void:
 # Explicit authored metre sections [z, half-width, half-height, centre-y].
 var rings: Array=[]
 for section: Array in sections:
  var z: float=float(section[0]);var w: float=float(section[1]);var h: float=float(section[2]);var y: float=float(section[3])
  rings.append([Vector3(-w,y-h,z),Vector3(w,y-h,z),Vector3(w,y+h,z),Vector3(-w,y+h,z)])
 var first: Array[Vector3]=[];var last: Array[Vector3]=[]
 for point: Vector3 in rings[0]:first.append(point)
 for point: Vector3 in rings[-1]:last.append(point)
 AviaAircraft._face(st,first,color,Vector3.FORWARD);AviaAircraft._face(st,last,color,Vector3.BACK)
 for i: int in range(1,rings.size()):
  for side: int in 4:
   var next: int=(side+1)%4
   AviaAircraft._face(st,[rings[i-1][side],rings[i-1][next],rings[i][next],rings[i][side]],color,[Vector3.DOWN,Vector3.RIGHT,Vector3.UP,Vector3.LEFT][side])

static func _fin(st: SurfaceTool,outline: Array,x: float,side: float,cant_degrees: float,color: Color) -> void:
 var left: Array[Vector3]=[];var right: Array[Vector3]=[]
 for point: Array in outline:
  var y: float=float(point[1]);var lean: float=side*tan(deg_to_rad(cant_degrees))*maxf(0,y-.25)
  left.append(Vector3(x+lean-.07,y,float(point[0])));right.append(Vector3(x+lean+.07,y,float(point[0])))
 AviaAircraft._face(st,left.duplicate(),color,Vector3.LEFT);AviaAircraft._face(st,right.duplicate(),color,Vector3.RIGHT)
 var center: Vector3=Vector3.ZERO
 for point: Vector3 in left:center+=point/float(left.size())
 for i: int in left.size():
  var j: int=(i+1)%left.size();var out: Vector3=(left[i]+left[j])*.5-center;out.x=0
  AviaAircraft._face(st,[left[i],left[j],right[j],right[i]],color,out)

static func _surface_pair(st: SurfaceTool,outline: Array,y: float,thickness: float,color: Color,dihedral_degrees: float=0) -> void:
 # Explicit authored convex half-planform, mirrored exactly; metres, nose -Z.
 for side: float in [-1.0,1.0]:
  var top: Array[Vector3]=[];var bottom: Array[Vector3]=[]
  for point: Array in outline:
   var height: float=y+tan(deg_to_rad(dihedral_degrees))*float(point[0])
   top.append(Vector3(side*float(point[0]),height+thickness*.5,float(point[1])))
   bottom.append(Vector3(side*float(point[0]),height-thickness*.5,float(point[1])))
  AviaAircraft._face(st,top.duplicate(),color,Vector3.UP);AviaAircraft._face(st,bottom.duplicate(),color,Vector3.DOWN)
  var center: Vector3=Vector3.ZERO
  for point: Vector3 in top:center+=point/float(top.size())
  for i: int in top.size():
   var j: int=(i+1)%top.size()
   var outward: Vector3=(top[i]+top[j])*.5-center;outward.y=0
   AviaAircraft._face(st,[bottom[i],bottom[j],top[j],top[i]],color,outward)

static func _build_airbrakes(root: AviaAircraft,spec: Dictionary,color: Color) -> void:
 var config: Dictionary=spec.get("visual",{}).get("airbrake_animation",{})
 if config.is_empty():return
 # Authored stylized add-on panels, not extracted/movable AI body geometry.
 # Only explicitly configured candidates receive them; no generic extra wings.
 var size_: Array=config.size_m
 var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 AviaAircraft._box(st,Vector3(0,0,float(size_[2])*.5),Vector3(float(size_[0]),float(size_[1]),float(size_[2])),color.lightened(.08))
 var template: MeshInstance3D=AviaAircraft._mesh(st,root,"AirbrakeTemplate",0,500)
 root.airbrake_instances=MultiMeshInstance3D.new();root.airbrake_instances.name="AuthoredAirbrakes"
 var instances: MultiMesh=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=template.mesh;instances.instance_count=config.panels.size()
 root.airbrake_instances.multimesh=instances;root.airbrake_instances.material_override=template.material_override;root.airbrake_instances.visibility_range_end=500
 root.add_child(root.airbrake_instances);template.free()
 root.airbrake_duration=float(config.travel_seconds)
 for panel: Dictionary in config.panels:
  var at: Array=panel.hinge_m
  root.airbrake_hinges.append(Transform3D(Basis.IDENTITY,Vector3(float(at[0]),float(at[1]),float(at[2]))))
  root.airbrake_angles.append(deg_to_rad(float(panel.angle_degrees)))
 root._pose_airbrake()

static func _build_flaps(root: AviaAircraft,spec: Dictionary,color: Color) -> void:
 var config: Dictionary=spec.get("visual",{}).get("flap_animation",{})
 if config.is_empty() or not bool(spec.systems.get("flaps",false)):return
 # Explicit provisional trailing-edge add-on skins, not extracted AI control surfaces.
 # Pair shares one small mesh/draw; all positions are measured against this candidate.
 var width: float=float(config.span_m);var sweep: float=float(config.hinge_sweep_m)
 var chord: float=float(config.chord_m);var tip: float=float(config.tip_chord_m)
 var thickness: float=float(config.thickness_m)
 var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 AviaAircraft._solid(st,[Vector3(0,-thickness*.5,0),Vector3(width,-thickness*.5,sweep),Vector3(width,-thickness*.5,sweep+tip),Vector3(0,-thickness*.5,chord),Vector3(0,thickness*.5,0),Vector3(width,thickness*.5,sweep),Vector3(width,thickness*.5,sweep+tip),Vector3(0,thickness*.5,chord)],color.lightened(.05))
 var template: MeshInstance3D=AviaAircraft._mesh(st,root,"FlapTemplate",0,500)
 root.flap_instances=MultiMeshInstance3D.new();root.flap_instances.name="AuthoredFlaps"
 var instances: MultiMesh=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=template.mesh;instances.instance_count=2
 root.flap_instances.multimesh=instances;root.flap_instances.material_override=template.material_override;root.flap_instances.visibility_range_end=500;root.add_child(root.flap_instances);template.free()
 root.flap_duration=clampf(float(config.travel_seconds),.2,2.0)
 var at: Array=config.hinge_m
 for side: float in [-1.0,1.0]:
  # Negative-X reflection mirrors the right-hand mesh; angle flips about the outward hinge.
  root.flap_hinges.append(Transform3D(Basis.from_scale(Vector3(side,1,1)),Vector3(side*float(at[0]),float(at[1]),float(at[2]))))
  root.flap_axes.append(Vector3(side*width,0,sweep).normalized())
  root.flap_angles.append(side*deg_to_rad(float(config.angle_degrees)))
 root._pose_flaps()

static func _nose_intake(st: SurfaceTool,config: Dictionary,color: Color,sides: int) -> void:
 # Own annular lip and exposed cone: no generic chin box on nose-intake references.
 var z: float=float(config.lip_z_m);var outer: float=float(config.outer_radius_m)
 var inner: float=float(config.inner_radius_m);var depth: Vector3=Vector3(0,0,float(config.depth_m))
 for segment: int in sides:
  var a: float=TAU*segment/sides;var b: float=TAU*(segment+1)/sides
  var oa: Vector3=Vector3(cos(a)*outer,sin(a)*outer,z);var ob: Vector3=Vector3(cos(b)*outer,sin(b)*outer,z)
  var ia: Vector3=Vector3(cos(a)*inner,sin(a)*inner,z);var ib: Vector3=Vector3(cos(b)*inner,sin(b)*inner,z)
  var radial: Vector3=Vector3(cos((a+b)*.5),sin((a+b)*.5),0)
  AviaAircraft._face(st,[oa,ob,ib,ia],color.lightened(.12),Vector3.FORWARD)
  AviaAircraft._face(st,[ia,ib,ib+depth,ia+depth],Color("162931"),-radial)
  AviaAircraft._face(st,[ob,oa,oa+depth,ob+depth],color,radial)
 var sections: Array[Vector3]=[]
 for section: Array in config.cone_sections_m:sections.append(Vector3(float(section[0]),float(section[1]),float(section[2])))
 AviaAircraft._loft(st,sections,0,Color("647b72"),sides)
