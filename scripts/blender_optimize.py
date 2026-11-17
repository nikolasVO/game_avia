"""Blender script. Fixture mode tests Blender only and is never labelled AI generation."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)
def main():
    p=argparse.ArgumentParser();p.add_argument("--manifest-name",default="manifest.json");p.add_argument("--input");p.add_argument("--fixture",action="store_true");p.add_argument("--output-dir",required=True)
    p.add_argument("--rotate-z-degrees",type=float,default=0);p.add_argument("--dimensions",type=float,nargs=3,default=[1,1,1]);p.add_argument("--triangles",type=int,default=5000);p.add_argument("--texture-size",type=int,default=1024)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    out=Path(a.output_dir);out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    if a.fixture:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj=bpy.context.object;obj.name="TechnicalFixture"
        mod=obj.modifiers.new("Bevel","BEVEL");mod.width=.06;mod.segments=3
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
        mat=bpy.data.materials.new("Orange");mat.diffuse_color=(.8,.2,.02,1);mat.use_nodes=True;mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.8,.2,.02,1);obj.data.materials.append(mat)
        bpy.ops.export_scene.gltf(filepath=str(out/"original.glb"),export_format="GLB")
        source_kind="procedural_test_fixture_not_TRELLIS"
    else:
        if not a.input:raise RuntimeError("input_required")
        bpy.ops.import_scene.gltf(filepath=str(Path(a.input).resolve()))
        source_kind="imported_mesh; consult_generation_manifest"
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not meshes:raise RuntimeError("no_mesh")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
    base=bpy.context.object;base.name="LOD0"
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.context.view_layer.update()
    orientation=Matrix.Rotation(math.radians(a.rotate_z_degrees),4,"Z")
    vertices=[orientation@(base.matrix_world@v.co) for v in base.data.vertices]
    low=Vector([min(v[i] for v in vertices) for i in range(3)])
    high=Vector([max(v[i] for v in vertices) for i in range(3)])
    if not all(math.isfinite(v) for v in (*low,*high)) or min(high-low)<=0:raise RuntimeError("invalid_bounds")
    center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for v in base.data.vertices:
        coord=orientation@(base.matrix_world@v.co)-center
        v.co=Vector([coord[i]/(high[i]-low[i])*a.dimensions[i] for i in range(3)])
    base.matrix_world.identity()
    base["lod"]=0
    if triangles(base)>a.triangles:
        mod=base.modifiers.new("Budget","DECIMATE");mod.ratio=a.triangles/triangles(base)*.97
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=base.modifiers.new("Triangulate","TRIANGULATE");bpy.ops.object.modifier_apply(modifier=mod.name)
    for im in bpy.data.images:
        if im.size[0]>a.texture_size or im.size[1]>a.texture_size:
            scale=a.texture_size/max(im.size);im.scale(max(1,int(im.size[0]*scale)),max(1,int(im.size[1]*scale)))
    lods=[]
    for level,ratio in ((1,min(.5,6000/max(1,triangles(base)))),(2,min(.25,1500/max(1,triangles(base))))):
        o=base.copy();o.data=base.data.copy();bpy.context.collection.objects.link(o);o.name="LOD"+str(level);o["lod"]=level
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new("LOD","DECIMATE");mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
        o.hide_render=True
        lods.append({"name":o.name,"triangles":triangles(o)})
    bpy.context.view_layer.objects.active=base
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,.5))
    collider=bpy.context.object;collider.name="COLLISION_BOX";collider["collision"]="box";collider.hide_render=True
    collider.dimensions=base.dimensions
    collider.location.z=base.dimensions.z/2
    collider.display_type="WIRE"
    # Independent LOD files avoid displaying all imported LODs/collision at once.
    lod_names=[]
    for obj in [base,*[bpy.data.objects[x["name"]] for x in lods]]:
        bpy.ops.object.select_all(action="DESELECT");obj.select_set(True)
        name=obj.name.lower()+".glb";lod_names.append(name)
        bpy.ops.export_scene.gltf(filepath=str(out/name),export_format="GLB",use_selection=True,export_yup=True)
    bpy.ops.export_scene.gltf(filepath=str(out/"optimized.glb"),export_format="GLB",export_extras=True,export_yup=True)
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.device="CPU";scene.cycles.samples=8
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    scene.world.color=(.3,.3,.3)
    bpy.ops.object.camera_add(location=tuple(v*max(a.dimensions) for v in (2,-3,2)))
    cam=bpy.context.object;direction=Vector((0,0,a.dimensions[2]/2))-cam.location;cam.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
    scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=max(a.dimensions)*1.8
    bpy.ops.object.light_add(type="AREA",location=(1,-2,4));bpy.context.object.data.energy=500;bpy.context.object.data.shape="DISK";bpy.context.object.data.size=4
    scene.render.filepath=str(out/"preview.png");bpy.ops.render.render(write_still=True)
    mats=len(base.data.materials);tris=triangles(base)
    base.data.calc_loop_triangles()
    degenerate=sum(1 for t in base.data.loop_triangles if t.area<1e-12)
    finite_geometry=all(math.isfinite(c) for v in base.data.vertices for c in (*v.co,*v.normal))
    uv_layers=len(base.data.uv_layers)
    texture_sizes=[list(im.size) for im in bpy.data.images if im.type=="IMAGE" and im.size[0]>0]
    from mathutils.kdtree import KDTree
    kd=KDTree(len(base.data.vertices))
    for i,v in enumerate(base.data.vertices):kd.insert(v.co,i)
    kd.balance()
    distances=[kd.find(Vector((-v.co.x,v.co.y,v.co.z)))[2] for v in base.data.vertices]
    symmetry={"mirror_axis":"Blender X","mean_distance_m":sum(distances)/len(distances),"max_distance_m":max(distances),"mean_fraction_width":sum(distances)/len(distances)/base.dimensions.x}

    manifest={"source_kind":source_kind,"blender_version":bpy.app.version_string,"triangles_lod0":tris,
              "materials_lod0":mats,"lods":lods,"collision":"box metadata only; engine binding required",
              "geometry":{"uv_layers":uv_layers,"degenerate_triangles":degenerate,"finite_vertices_and_normals":finite_geometry,"texture_sizes":texture_sizes,"symmetry":symmetry},
              "generator_script_sha256":digest(__file__),"dimensions_m":[base.dimensions.x,base.dimensions.z,base.dimensions.y],"pivot":"bottom_center","source_yaw_degrees":a.rotate_z_degrees,"export_axes":"glTF Y-up",
              "unity_import_tested":False,"license":"CC0 procedural fixture" if a.fixture else "see source manifest",
              "checks":{"triangle_budget":tris<=a.triangles,"material_budget":mats<=2,"finite_bounds":True,"finite_geometry":finite_geometry,"no_degenerate_triangles":degenerate==0,"uv_present":uv_layers>0 if not a.fixture else True,"texture_budget":all(max(size)<=a.texture_size for size in texture_sizes)},
              "files":{n:{"sha256":digest(out/n),"bytes":(out/n).stat().st_size} for n in ["optimized.glb","preview.png",*lod_names]}}
    manifest["verified"]=all(manifest["checks"].values())
    temp=out/(a.manifest_name+".tmp");temp.write_text(json.dumps(manifest,indent=2));temp.replace(out/a.manifest_name)
    if not manifest["verified"]:raise RuntimeError("asset_budget_failed")
    print("GAME_AVIA_BLENDER_RESULT="+json.dumps(manifest))
if __name__=="__main__":main()

