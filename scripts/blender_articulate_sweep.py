"""Separate a verified open-wing candidate; no inference and no original overwrite."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clipped(source, name, side, hinge, aft):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Partition at exact planes first: no face belongs to two moving pieces.
    for point, normal in (((hinge, 0, 0), (1, 0, 0)), ((-hinge, 0, 0), (1, 0, 0)), ((0, aft, 0), (0, 1, 0))):
        bmesh.ops.bisect_plane(bm, geom=[*bm.verts, *bm.edges, *bm.faces],
                               dist=1e-6, plane_co=point, plane_no=normal)
    remove = []
    for face in bm.faces:
        center = face.calc_center_median()
        wing = abs(center.x) > hinge and center.y < aft
        keep = (not wing) if side == 0 else wing and center.x * side > 0
        if not keep:
            remove.append(face)
    bmesh.ops.delete(bm, geom=remove, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    obj.data.calc_loop_triangles()
    if not obj.data.loop_triangles:
        raise RuntimeError('empty_articulated_part:' + name)
    if any(t.area <= 1e-12 for t in obj.data.loop_triangles):
        raise RuntimeError('degenerate_articulated_part:' + name)
    if not all(math.isfinite(c) for v in obj.data.vertices for c in v.co):
        raise RuntimeError('nonfinite_articulated_part:' + name)
    return obj


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--input-dir', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--hinge-x', type=float, default=2.8)
    p.add_argument('--hinge-z', type=float, default=-.5)
    p.add_argument('--hinge-height', type=float, default=1.27)
    p.add_argument('--aft-limit-z', type=float, default=4.8)
    a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if a.input_dir.resolve() == a.output_dir.resolve():
        raise RuntimeError('separate_derivative_directory_required')
    a.output_dir.mkdir(parents=True, exist_ok=True)
    original_hashes = {f'lod{i}.glb': digest(a.input_dir / f'lod{i}.glb') for i in range(3)}
    result = {'method': 'exact plane partition; original UV and materials retained',
              'axes': 'glTF/Godot Y-up, -Z forward', 'source_files': original_hashes,
              'script_sha256': digest(Path(__file__)), 'blender_version': bpy.app.version_string,
              'hinge_m': [a.hinge_x, a.hinge_height, a.hinge_z],
              'aft_limit_z_m': a.aft_limit_z, 'production_accepted': False, 'lods': [], 'files': {}}
    for level in range(3):
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        bpy.ops.import_scene.gltf(filepath=str((a.input_dir / f'lod{level}.glb').resolve()))
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        if len(meshes) != 1:
            raise RuntimeError('expected_single_source_mesh')
        source = meshes[0]
        bpy.context.view_layer.objects.active = source
        source.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        source.data.calc_loop_triangles()
        source_area = sum(t.area for t in source.data.loop_triangles)
        # glTF importer maps game (x,y,z) to Blender (x,-z,y).
        # Reflect Y during clipping to express the aft limit in game coordinates.
        for v in source.data.vertices:
            v.co.y = -v.co.y
        parts = [clipped(source, f'LOD{level}', 0, a.hinge_x, a.aft_limit_z)]
        for side, label in ((-1, 'Left'), (1, 'Right')):
            parts.append(clipped(source, f'LOD{level}Wing{label}', side, a.hinge_x, a.aft_limit_z))
        partition_area = sum(sum(t.area for t in o.data.loop_triangles) for o in parts)
        if abs(partition_area - source_area) / source_area > 1e-5:
            raise RuntimeError('partition_lost_or_duplicated_surface')
        cut_triangles = sum(len(o.data.loop_triangles) for o in parts)
        target = (19500, 6600, 1800)[level]
        if cut_triangles > target:
            for obj in parts:
                bpy.context.view_layer.objects.active = obj
                mod = obj.modifiers.new('PartitionBudget', 'DECIMATE')
                mod.ratio = target / cut_triangles * .98
                bpy.ops.object.modifier_apply(modifier=mod.name)
        for obj in parts:
            for v in obj.data.vertices:
                v.co.y = -v.co.y
            # Reflection twice retains original winding and UV interpolation.
            obj.data.update()
        bpy.data.objects.remove(source, do_unlink=True)
        rows = []
        for obj in parts:
            if 'Wing' in obj.name:
                side = -1 if 'Left' in obj.name else 1
                pivot = Vector((side * a.hinge_x, -a.hinge_z, a.hinge_height))
                for vertex in obj.data.vertices:
                    vertex.co -= pivot
                obj.location = pivot
            obj.data.calc_loop_triangles()
            if any(t.area <= 1e-12 for t in obj.data.loop_triangles):
                raise RuntimeError('degenerate_after_partition_budget')
            rows.append({'name': obj.name, 'triangles': len(obj.data.loop_triangles)})
        triangles = sum(row['triangles'] for row in rows)
        if triangles > (20000, 7000, 2000)[level]:
            raise RuntimeError('articulated_lod_budget_exceeded')
        name = f'articulated-lod{level}.glb'
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=str((a.output_dir / name).resolve()), export_format='GLB',
                                  use_selection=True, export_yup=True)
        result['lods'].append({'level': level, 'triangles': triangles, 'parts': rows,
                              'source_area_m2': source_area, 'partition_area_m2': partition_area,
                              'triangles_before_budget': cut_triangles})
        path = a.output_dir / name
        result['files'][name] = {'sha256': digest(path), 'bytes': path.stat().st_size}
    if any(digest(a.input_dir / name) != sha for name, sha in original_hashes.items()):
        raise RuntimeError('original_changed')
    (a.output_dir / 'articulation-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
