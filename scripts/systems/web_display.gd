extends Node
## Web / mobile display helpers: Fullscreen API (with webkit fallbacks), landscape
## lock where supported, and canvas fill. First user tap requests fullscreen on web.


var _fs_requested: bool = false
var _js_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_js_available = OS.has_feature("web")
	if _js_available:
		_inject_boot_js()
		set_process_unhandled_input(true)
	# Prefer landscape on phones (native + web where supported).
	if DisplayServer.has_method("screen_set_orientation"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)


func _inject_boot_js() -> void:
	if not OS.has_feature("web"):
		return
	# Keep canvas edge-to-edge; hide scrollbars; safe-area aware. Safe to re-run.
	JavaScriptBridge.eval("""
(function () {
  if (window.__farsighDisplayBoot) return;
  window.__farsighDisplayBoot = true;
  var css = document.createElement('style');
  css.textContent = [
    'html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#000;',
    'touch-action:none;-webkit-text-size-adjust:100%;}',
    '#canvas,canvas{display:block;width:100vw!important;height:100vh!important;',
    'max-width:100vw;max-height:100vh;position:fixed;left:0;top:0;',
    'padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);',
    'box-sizing:border-box;background:#000;}',
    'body.farsigh-fs #canvas,body.farsigh-fs canvas{width:100vw!important;height:100vh!important;}'
  ].join('');
  document.head.appendChild(css);
  window.__farsighIsFullscreen = function () {
    return !!(document.fullscreenElement || document.webkitFullscreenElement || document.msFullscreenElement);
  };
  window.__farsighRequestFullscreen = function () {
    var el = document.documentElement;
    var req = el.requestFullscreen || el.webkitRequestFullscreen || el.webkitRequestFullScreen
      || el.msRequestFullscreen || el.mozRequestFullScreen;
    var canvas = document.getElementById('canvas') || document.querySelector('canvas');
    var target = canvas || el;
    var treq = target.requestFullscreen || target.webkitRequestFullscreen || target.webkitRequestFullScreen
      || target.msRequestFullscreen;
    try {
      if (treq) treq.call(target);
      else if (req) req.call(el);
    } catch (e) {}
    try {
      if (screen.orientation && screen.orientation.lock) {
        screen.orientation.lock('landscape').catch(function(){});
      } else if (screen.lockOrientation) {
        screen.lockOrientation('landscape');
      } else if (screen.mozLockOrientation) {
        screen.mozLockOrientation('landscape');
      }
    } catch (e2) {}
    document.body.classList.add('farsigh-fs');
    return true;
  };
  window.__farsighExitFullscreen = function () {
    var ex = document.exitFullscreen || document.webkitExitFullscreen || document.msExitFullscreen
      || document.mozCancelFullScreen;
    try { if (ex) ex.call(document); } catch (e) {}
    document.body.classList.remove('farsigh-fs');
    return true;
  };
  window.__farsighToggleFullscreen = function () {
    if (window.__farsighIsFullscreen()) return window.__farsighExitFullscreen();
    return window.__farsighRequestFullscreen();
  };
})();
""", true)


func _unhandled_input(event: InputEvent) -> void:
	if not _js_available or _fs_requested:
		return
	# First real user gesture → request fullscreen (Browsers require a gesture).
	var gest := false
	if event is InputEventMouseButton and event.pressed:
		gest = true
	elif event is InputEventScreenTouch and event.pressed:
		gest = true
	elif event is InputEventKey and event.pressed:
		gest = true
	if gest:
		_fs_requested = true
		request_fullscreen()


func is_fullscreen() -> bool:
	if _js_available:
		var v = JavaScriptBridge.eval("window.__farsighIsFullscreen ? window.__farsighIsFullscreen() : false", true)
		return bool(v)
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func request_fullscreen() -> void:
	if _js_available:
		JavaScriptBridge.eval("window.__farsighRequestFullscreen && window.__farsighRequestFullscreen()", true)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func exit_fullscreen() -> void:
	if _js_available:
		JavaScriptBridge.eval("window.__farsighExitFullscreen && window.__farsighExitFullscreen()", true)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_fullscreen() -> void:
	if is_fullscreen():
		exit_fullscreen()
	else:
		request_fullscreen()
