extends Node
## data/*.json (2D판 src/data 를 tools/export_data.mjs 로 옮긴 것)을 한 번 읽어 둔다.
##
##   Data.get_module("maps").MAPS.VILLAGE
##
## JSON 은 숫자를 전부 float 로 읽는다. 타일 좌표처럼 정수로 써야 하는 곳은 쓰는 쪽에서 int() 로 바꾼다.
## 데이터 속 함수 자리({ "$fn", "$at" })는 Conditions 에 옮겨 둔 Callable 로 바꿔 끼운다.

var _modules := {}


func get_module(name: String) -> Dictionary:
	if not _modules.has(name):
		var path := "res://data/%s.json" % name
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("데이터를 못 읽었다: " + path)
			parsed = {}
		_modules[name] = _resolve(name, parsed)
	return _modules[name]


func _resolve(module: String, v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("$fn"):
			var fn = Conditions.lookup(module, v["$at"])
			if fn == null:
				push_warning("아직 GDScript 로 옮기지 않은 데이터 함수: %s:%s" % [module, v["$at"]])
				return func(_s = null): return false
			return fn
		for k in v: v[k] = _resolve(module, v[k])
	elif v is Array:
		for i in v.size(): v[i] = _resolve(module, v[i])
	return v
