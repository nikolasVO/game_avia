"""Owned procedural reference. Run with Blender; no image API or borrowed plane."""
import bpy, math, json, hashlib, sys
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index('--')+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.55
    return m
orange=mat('Warm terracotta',(.72,.20,.055));cream=mat('Warm ivory',(.88,.81,.57));teal=mat('Deep teal',(.025,.23,.26));glass=mat('Blue canopy',(.045,.13,.19))
def ellipsoid(name,loc,scale,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return o
def box(name,loc,scale,material,bevel=.1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    m=o.modifiers.new('Rounded edges','BEVEL');m.width=bevel;m.segments=2
    bpy.ops.object.modifier_apply(modifier=m.name)
    return o
ellipsoid('Fuselage',(0,0,1.1),(.65,3.5,.67),orange)
ellipsoid('Canopy',(0,-.65,1.64),(.46,1.15,.46),glass)
box('Main wing',(0,-.25,1.0),(10,1.65,.18),cream)
box('Tailplane',(0,2.65,1.23),(3.7,.95,.14),teal)
box('Vertical tail',(0,2.6,1.9),(.16,1.05,1.6),teal)
ellipsoid('Nose',(0,-3.35,1.1),(.44,.55,.44),teal)
# Two visible short fixed landing legs and wheels, no trademark or real aircraft tracing.
for x in (-1.1,1.1):
    box('Landing strut',(x,-.65,.54),(.12,.18,.9),teal,.03)
    wheel=ellipsoid('Wheel',(x,-.65,.22),(.18,.34,.34),glass)
bpy.ops.export_scene.gltf(filepath=str(out/'trellis_validation_plane_reference.glb'),export_format='GLB')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100;scene.render.film_transparent=True
bpy.ops.object.camera_add(location=(12,-15,12));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=13;scene.camera=cam
for loc,power,size in (((-3,-5,10),1800,8),((5,3,7),1200,6)):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.45,.45,.45)
png=out/'trellis_validation_plane_reference.png';scene.render.filepath=str(png);bpy.ops.render.render(write_still=True)
data={'source_kind':'owned_procedural_aircraft_render','license':'CC0-1.0 for project-authored procedural geometry and reference','paid_image_api':False,'description':'Original terracotta and ivory high-wing toy aircraft; no third-party reference','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'files':{p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in (png,out/'trellis_validation_plane_reference.glb')}}
(out/'trellis_validation_plane_reference.manifest.json').write_text(json.dumps(data,indent=2)+'\n')
