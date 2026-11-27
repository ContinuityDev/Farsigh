extends RefCounted
class_name ThreadedLoader
## ResourceLoader.load_threaded_request when the platform supports it, with a
## frame-polled fallback for single-threaded web (Godot Pages builds).


static func supports_threads() -> bool:
	# Web export for Pages is compiled with variant/thread_support=false.
	if OS.has_feature("web"):
		return false
	return true


## Load a resource across frames. Pass a Node that can await process_frame.
## Returns null and fills `out_error` on failure.
static func load_async(host: Node, path: String, type_hint: String = "", out_error: Array = []) -> Resource:
	if path == "" or not ResourceLoader.exists(path):
		var msg := "Missing resource: %s" % path
		push_error("[ThreadedLoader] %s" % msg)
		print("OUTPOST_LOAD_ERROR ", msg)
		if out_error != null:
			out_error.append(msg)
		return null

	# Prefer threaded request when available; on single-thread web Godot still
	# accepts the API but completes during status polls — we yield between polls
	# so the loading screen / WebGL can breathe (chunked fallback).
	var err := ResourceLoader.load_threaded_request(path, type_hint, false)
	if err != OK:
		# Fallback: sync load on a deferred frame boundary
		await host.get_tree().process_frame
		var sync_res := ResourceLoader.load(path, type_hint)
		if sync_res == null:
			var msg2 := "Failed to load %s (err %d)" % [path, err]
			push_error("[ThreadedLoader] %s" % msg2)
			print("OUTPOST_LOAD_ERROR ", msg2)
			if out_error != null:
				out_error.append(msg2)
		return sync_res

	var frames := 0
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				var msg3 := "Threaded load failed: %s" % path
				push_error("[ThreadedLoader] %s" % msg3)
				print("OUTPOST_LOAD_ERROR ", msg3)
				if out_error != null:
					out_error.append(msg3)
				return null
			_:
				frames += 1
				if frames > 600:
					var msg4 := "Timed out loading %s" % path
					push_error("[ThreadedLoader] %s" % msg4)
					print("OUTPOST_LOAD_ERROR ", msg4)
					if out_error != null:
						out_error.append(msg4)
					return null
				await host.get_tree().process_frame
	return null
