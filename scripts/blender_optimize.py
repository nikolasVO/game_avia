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
def mirror_decimate(obj,budget):
    """Bisect to +X, simplify that half, then mirror; preserve loop UVs/materials."""
    import bmesh
    bpy.context.view_layer.objects.active=obj
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm,geom=[*bm.verts,*bm.edges,*bm.faces],dist=1e-6,
                          plane_co=Vector((0,0,0)),plane_no=Vector((1,0,0)),clear_inner=True,clear_outer=False)
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    half=triangles(obj)
    if not half:raise RuntimeError("empty_symmetry_half")
    ratio=min(1,max(1,budget*.5-16)/half)
    if ratio<1:
        mod=obj.modifiers.new("SymmetricBudget","DECIMATE");mod.ratio=ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=obj.modifiers.new("ExactMirrorX","MIRROR");mod.use_clip=True;mod.use_mirror_merge=True;mod.merge_threshold=1e-5
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    mod=obj.modifiers.new("TriangulateSymmetry","TRIANGULATE");bpy.ops.object.modifier_apply(modifier=mod.name)

def remesh_far_lod(obj,dimensions,budget,symmetric):
    """Close fragmented boundary topology for far LOD; use a plain sampled material."""
    color=(.5,.6,.65,1)
    if obj.data.materials:
        source=obj.data.materials[0]
        color=tuple(source.diffuse_color)
        if source.use_nodes:
            principled=next((n for n in source.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if principled:color=tuple(principled.inputs['Base Color'].default_value)
            image=next((n.image for n in source.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB'),None)
            if image and obj.data.uv_layers.active:
                pixels=image.pixels[:];w,h=image.size;uvs=obj.data.uv_layers.active.data
                samples=[]
                for face in list(obj.data.polygons)[::max(1,len(obj.data.polygons)//128)]:
                    uv=sum((uvs[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
                    offset=(min(h-1,max(0,int(uv.y*h)))*w+min(w-1,max(0,int(uv.x*w))))*4
                    samples.append(pixels[offset:offset+3])
                if samples:color=tuple(sum(v[i] for v in samples)/len(samples) for i in range(3))+(1,)
    bpy.context.view_layer.objects.active=obj
    # Rebuild each attempt from the unmodified near geometry. Thin fragmented wings
    # can leave a floor above the budget after a fine voxel pass and decimation.
    source_mesh=obj.data.copy();attempts=[]
    for fraction in (.002,.003,.004,.006):
        obj.data=source_mesh.copy()
        mod=obj.modifiers.new('FarTopologyRepair','REMESH');mod.mode='VOXEL';mod.voxel_size=max(dimensions)*fraction
        voxel=mod.voxel_size
        bpy.ops.object.modifier_apply(modifier=mod.name)
        if symmetric:mirror_decimate(obj,budget)
        elif triangles(obj)>budget:
            mod=obj.modifiers.new('FarBudget','DECIMATE');mod.ratio=budget/triangles(obj)*.97;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.update()
        attempts.append({'voxel_size_m':voxel,'triangles':triangles(obj),'dimensions_blender':list(obj.dimensions)})
        if triangles(obj)<=2000:break
    plain=bpy.data.materials.new('FarSampledAlbedo');plain.use_nodes=True;plain.diffuse_color=color
    plain.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=color
    plain.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.9
    obj.data.materials.clear();obj.data.materials.append(plain)
    return {'method':'voxel topology repair then decimation','attempts':attempts,'voxel_size_m':voxel,'material':'plain sampled albedo; no far texture/UV required','rgba':list(color)}

def main():
    p=argparse.ArgumentParser();p.add_argument("--manifest-name",default="manifest.json");p.add_argument("--input");p.add_argument("--fixture",action="store_true");p.add_argument("--output-dir",required=True)
    p.add_argument("--symmetry-x",action="store_true");p.add_argument("--fixture-asymmetric",action="store_true");p.add_argument("--rotate-z-degrees",type=float,default=0);p.add_argument("--dimensions",type=float,nargs=3,default=[1,1,1]);p.add_argument("--triangles",type=int,default=5000);p.add_argument("--texture-size",type=int,default=1024)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    out=Path(a.output_dir);out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    if a.fixture:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj=bpy.context.object;obj.name="TechnicalFixture"
        mod=obj.modifiers.new("Bevel","BEVEL");mod.width=.06;mod.segments=3
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
        if a.fixture_asymmetric:
            obj.data.vertices[0].co.x+=.3;obj.data.vertices[0].co.z+=.18
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
    if a.symmetry_x:
        mirror_decimate(base,a.triangles)
        # Cutting an asymmetric fin/nose can change extrema; restore explicit game dimensions.
        coords=[v.co.copy() for v in base.data.vertices]
        lo=Vector([min(v[i] for v in coords) for i in range(3)]);hi=Vector([max(v[i] for v in coords) for i in range(3)])
        center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
        for vertex in base.data.vertices:vertex.co=Vector([(vertex.co[i]-center[i])/(hi[i]-lo[i])*a.dimensions[i] for i in range(3)])
        base.data.update();bpy.context.view_layer.update()
    elif triangles(base)>a.triangles:
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
        if a.symmetry_x:mirror_decimate(o,max(100,int(triangles(base)*ratio)))
        else:
            mod=o.modifiers.new("LOD","DECIMATE");mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
        repair=None
        target=6000 if level==1 else 1500
        if level==2 and triangles(o)>target:
            o.data=base.data.copy()
            repair=remesh_far_lod(o,a.dimensions,target,a.symmetry_x)
        o.hide_render=True
        bpy.context.view_layer.update()
        lods.append({"name":o.name,"triangles":triangles(o),"far_repair":repair,"dimensions_blender":list(o.dimensions)})
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
              "generator_script_sha256":digest(__file__),"dimensions_m":[base.dimensions.x,base.dimensions.z,base.dimensions.y],"pivot":"bottom_center","source_yaw_degrees":a.rotate_z_degrees,"symmetry_enforced_x":a.symmetry_x,"export_axes":"glTF Y-up",
              "unity_import_tested":False,"license":"CC0 procedural fixture" if a.fixture else "see source manifest",
              "checks":{"triangle_budget":tris<=a.triangles,"material_budget":mats<=2,"finite_bounds":True,"finite_geometry":finite_geometry,"no_degenerate_triangles":degenerate==0,"uv_present":uv_layers>0 if not a.fixture else True,"texture_budget":all(max(size)<=a.texture_size for size in texture_sizes)},
              "files":{n:{"sha256":digest(out/n),"bytes":(out/n).stat().st_size} for n in ["optimized.glb","preview.png",*lod_names]}}
    manifest["checks"]["lod_budgets"]=all(row["triangles"]<=(7000 if row["name"]=="LOD1" else 2000) for row in lods)
    manifest["checks"]["lod_silhouette_bounds"]=all(all(.85<=row["dimensions_blender"][i]/a.dimensions[i]<=1.1 for i in range(3)) for row in lods)
    if a.symmetry_x:manifest["checks"]["exact_mirror_symmetry"]=symmetry["max_distance_m"]<1e-4
    manifest["verified"]=all(manifest["checks"].values())
    temp=out/(a.manifest_name+".tmp");temp.write_text(json.dumps(manifest,indent=2));temp.replace(out/a.manifest_name)
    if not manifest["verified"]:raise RuntimeError("asset_budget_failed")
    print("GAME_AVIA_BLENDER_RESULT="+json.dumps(manifest))
if __name__=="__main__":main()

