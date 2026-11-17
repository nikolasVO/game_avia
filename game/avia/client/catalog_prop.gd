class_name AviaCatalogProp
extends RefCounted
## Imported catalog LODs are separate meshes. Hide authoring colliders and activate one range.
static func build(packed: PackedScene) -> Node3D:
 var root: Node3D=packed.instantiate()
 configure(root)
 return root
static func configure(node: Node) -> void:
 if node is MeshInstance3D:
  var mesh: MeshInstance3D=node
  if str(node.name).begins_with("COLLISION"):
   mesh.hide() # Decorative prop; server flight collision remains independent.
  else:
   var level: int=0
   if str(node.name).begins_with("LOD1"):level=1
   elif str(node.name).begins_with("LOD2"):level=2
   mesh.visibility_range_begin=[0.0,350.0,900.0][level]
   mesh.visibility_range_end=[350.0,900.0,2500.0][level]
   for i: int in range(mesh.mesh.get_surface_count()):
    var material: Material=mesh.get_active_material(i)
    if material is BaseMaterial3D:
     material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
     # Matte wooden safety prop: keep generated albedo, avoid unused PBR texture work.
     material.normal_enabled=false;material.metallic=0;material.roughness=0.9
     for slot: int in [BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:material.set_texture(slot,null)
 for child: Node in node.get_children():configure(child)
