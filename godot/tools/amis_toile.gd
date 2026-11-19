extends SceneTree
## Lot V2-AMIS : transforme les toiles simulées par tools/gen_bache.py (<dossier>/<nom>.bin et .json) en
## maillages Godot (ArrayMesh) enregistrés dans res://assets/models/amis/<nom>.res.
## godot --headless --path godot --script res://tools/amis_toile.gd -- <dossier> bache_lit housse_bergere
## (gen_bache.py écrit les .bin et .json ; Godot peut finir par « Aborted » en quittant : les .res sont écrits)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/amis"))
	for k in range(1, args.size()):
		var nm := args[k]
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(nm + ".json")))
		var nvert := int(info.vertices)
		var nidx := int(info.indices)
		var f := FileAccess.open(dir.path_join(nm + ".bin"), FileAccess.READ)
		var pos := f.get_buffer(nvert * 12).to_float32_array()
		var nrm := f.get_buffer(nvert * 12).to_float32_array()
		var tan := f.get_buffer(nvert * 16).to_float32_array()
		var uv := f.get_buffer(nvert * 8).to_float32_array()
		var idx := f.get_buffer(nidx * 4).to_int32_array()
		var v3 := PackedVector3Array()
		var n3 := PackedVector3Array()
		var u2 := PackedVector2Array()
		v3.resize(nvert)
		n3.resize(nvert)
		u2.resize(nvert)
		for i in nvert:
			v3[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
			n3[i] = Vector3(nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2])
			u2[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v3
		arrays[Mesh.ARRAY_NORMAL] = n3
		arrays[Mesh.ARRAY_TANGENT] = tan
		arrays[Mesh.ARRAY_TEX_UV] = u2
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		mesh.resource_name = nm
		var path := "res://assets/models/amis/%s.res" % nm
		var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		print("TOILE ", nm, " : ", nvert, " sommets, ", nidx / 3, " triangles, aabb ", mesh.get_aabb(), " -> ", path, " (", err, ")")
	quit()
