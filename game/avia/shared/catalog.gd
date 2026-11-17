class_name AviaCatalog
extends RefCounted
## Single data source for UI, authority and prediction; stable indices preserve originals 0..2.
static var _all: Array[Dictionary]=[]
static var _playable: Array[Dictionary]=[]
static func all() -> Array[Dictionary]:
 if not _all.is_empty():return _all
 var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/aircraft/catalog.json"))
 for id: String in index.order:
  var row: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/aircraft/"+id+".json"))
  _all.append(row)
  if row.playable:
   var spec: Dictionary=row.duplicate(true)
   spec.name=row.display_name;spec.color=Color(row.color);spec.stall=float(row.flight.stall_speed_kmh)/3.6;spec.max=float(row.flight.max_speed_altitude_kmh)/3.6
   if row.has("legacy"):spec.merge(row.legacy,true)
   _playable.append(spec)
 return _all
static func playable() -> Array[Dictionary]:
 all()
 return _playable
static func index_of(id: String) -> int:
 var rows: Array[Dictionary]=playable()
 for i: int in rows.size():
  if rows[i].aircraft_id==id:return i
 return -1
