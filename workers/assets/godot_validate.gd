extends SceneTree

var mesh_rows: Array = []
var bounds := AABB()
var have_bounds := false
var check_ok := true
var preview_path := ""
var lod_meshes: Array = [[], [], []]
var lod_triangles: Array[int] = [0,0,0]

func _initialize() -> void:
    call_deferred("validate_asset")

func walk(node: Node) -> void:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        var row := {"name": str(node.name), "triangles": 0, "surfaces": instance.mesh.get_surface_count(), "materials": 0, "textures": 0}
        for i in range(instance.mesh.get_surface_count()):
            var arrays := instance.mesh.surface_get_arrays(i)
            var indices = arrays[Mesh.ARRAY_INDEX]
            row.triangles += (indices.size() if indices != null and indices.size() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
            var material := instance.get_active_material(i)
            if material != null:
                row.materials += 1
                if material is StandardMaterial3D and material.albedo_texture != null:
                    row.textures += 1
        var level := -1
        for i in 3:
            if str(node.name).begins_with("LOD"+str(i)): level=i
        if level>=0:
            lod_meshes[level].append(instance)
            lod_triangles[level]+=int(row.triangles)
            check_ok=check_ok and row.triangles>0 and row.materials>0
        if level==0:
            bounds = instance.global_transform * instance.mesh.get_aabb()
            have_bounds = true
            check_ok = check_ok and row.triangles > 0 and row.materials > 0
        else:
            instance.visible = false
        mesh_rows.append(row)
    for child in node.get_children():
        walk(child)

func validate_asset() -> void:
    var args := OS.get_cmdline_user_args()
    var scene := load("res://optimized.glb") as PackedScene
    if scene == null:
        push_error("GLB import failed")
        quit(1)
        return
    var world := Node3D.new()
    root.add_child(world)
    var model := scene.instantiate()
    world.add_child(model)
    walk(model)
    check_ok = check_ok and have_bounds and mesh_rows.size() >= 4
    var expected := Vector3(float(args[1]), float(args[2]), float(args[3]))
    var dimensions_ok := bounds.size.distance_to(expected) < 0.02
    var pivot_ok: bool = abs(bounds.position.y) < 0.01 and abs(bounds.get_center().x) < 0.01 and abs(bounds.get_center().z) < 0.01
    check_ok = check_ok and dimensions_ok and pivot_ok and bounds.size.is_finite()
    for level in 3:
        check_ok=check_ok and lod_triangles[level]>0 and lod_triangles[level]<=[20000,7000,2000][level]
        for instance: MeshInstance3D in lod_meshes[level]:
            var size: Vector3=(instance.global_transform*instance.mesh.get_aabb()).size
            for axis in 3:check_ok=check_ok and size[axis]/expected[axis]>=.85 and size[axis]/expected[axis]<=1.1
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.12, 0.17, 0.22)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color.WHITE
    environment.environment.ambient_light_energy = 0.7
    world.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45,-30,0)
    world.add_child(light)
    var camera := Camera3D.new()
    world.add_child(camera)
    var longest: float = max(bounds.size.x,max(bounds.size.y,bounds.size.z))
    camera.position = bounds.get_center() + Vector3(1.3,1.0,1.7) * longest
    camera.look_at(bounds.get_center())
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = longest*1.6
    camera.current = true
    await process_frame
    await process_frame
    var preview_ok := false
    var preview_files: Array = []
    if DisplayServer.get_name() != "headless":
        for level in 3:
          for other in 3:
            for mesh: MeshInstance3D in lod_meshes[other]:mesh.visible=other==level
          for view in ["orbit", "top", "front", "side"]:
            if view == "orbit":
                camera.position=bounds.get_center()+Vector3(1.3,1.0,1.7)*longest
                camera.look_at(bounds.get_center())
            if view == "top":
                camera.position = bounds.get_center() + Vector3(0,2,0) * longest
                camera.look_at(bounds.get_center(),Vector3.FORWARD)
            elif view == "front":
                camera.position = bounds.get_center() + Vector3(0,0.15,-2) * longest
                camera.look_at(bounds.get_center())
            elif view == "side":
                camera.position = bounds.get_center() + Vector3(2,0.15,0) * longest
                camera.look_at(bounds.get_center())
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
            var img := root.get_texture().get_image()
            var filename: String = "godot-preview.png" if view == "orbit" else "godot-"+view+".png"
            if level>0:filename="godot-lod"+str(level)+"-"+view+".png"
            preview_path = args[0].get_base_dir().path_join(filename)
            preview_ok = img.save_png(preview_path) == OK
            check_ok = check_ok and preview_ok
            preview_files.append(filename)
    var result := {"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "import_passed": check_ok, "dimensions_ok": dimensions_ok, "pivot_ok": pivot_ok, "bounds_position": [bounds.position.x,bounds.position.y,bounds.position.z], "dimensions": [bounds.size.x,bounds.size.y,bounds.size.z], "lod_triangles":lod_triangles,"meshes": mesh_rows, "preview_rendered": preview_ok, "preview_files": preview_files}
    var f := FileAccess.open(args[0],FileAccess.WRITE)
    f.store_string(JSON.stringify(result,"  ")+"\n")
    print("GODOT_ASSET_VALIDATION="+JSON.stringify(result))
    quit(0 if check_ok else 1)
