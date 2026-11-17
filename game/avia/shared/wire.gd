class_name AviaWire
extends RefCounted
## Fixed-width numeric snapshots: no resource/object deserialization. Versioned with protocol.
const STRIDE: int=84
static func pack(players: Dictionary) -> PackedByteArray:
 var data: PackedByteArray=PackedByteArray();data.resize(players.size()*STRIDE)
 var offset: int=0
 for id: int in players:
  var player: Dictionary=players[id];var s: Dictionary=player.state
  data.encode_u32(offset,id);data.encode_u32(offset+4,int(player.ack));data.encode_u32(offset+8,int(s.age))
  var values: Array[float]=[s.p.x,s.p.y,s.p.z,s.v.x,s.v.y,s.v.z,s.pitch,s.yaw,s.roll,s.health,s.distance]
  for i: int in range(values.size()):data.encode_float(offset+12+i*4,values[i])
  var flags: int=int(s.crashed) | (int(s.grounded)<<1) | (int(s.was_airborne)<<2) | (int(s.landed)<<3)
  flags|=(int(s.get("gear",true))<<4) | (int(s.get("flaps",false))<<5) | (int(s.get("afterburner",false))<<6) | (int(s.get("airbrake",false))<<7) | (int(s.get("profile",0))<<8)
  data.encode_u32(offset+56,flags);data.encode_u32(offset+60,int(s.plane));data.encode_u32(offset+64,int(player.race.get("next",0)))
  data.encode_u32(offset+68,int(player.race.get("start",0)));data.encode_float(offset+72,float(player.race.get("time",0)))
  data.encode_u32(offset+76,int(player.score));var rates: Vector3=s.get("rates",Vector3.ZERO)
  var rate_bits: int=0
  for j: int in 3:rate_bits|=((int(round(rates[j]*32.0))+128) & 255)<<(8+j*8)
  data.encode_u32(offset+80,mini(int(s.respawns),255) | rate_bits)
  offset+=STRIDE
 return data
static func unpack(data: PackedByteArray) -> Dictionary:
 if data.size() % STRIDE!=0 or data.size()>16*STRIDE:return {}
 var result: Dictionary={}
 for offset: int in range(0,data.size(),STRIDE):
  var flags: int=data.decode_u32(offset+56)
  var s: Dictionary={"p":Vector3(data.decode_float(offset+12),data.decode_float(offset+16),data.decode_float(offset+20)),"v":Vector3(data.decode_float(offset+24),data.decode_float(offset+28),data.decode_float(offset+32)),
  "pitch":data.decode_float(offset+36),"yaw":data.decode_float(offset+40),"roll":data.decode_float(offset+44),"health":data.decode_float(offset+48),"distance":data.decode_float(offset+52),
  "crashed":bool(flags & 1),"grounded":bool(flags & 2),"was_airborne":bool(flags & 4),"landed":bool(flags & 8),"plane":data.decode_u32(offset+60),"age":data.decode_u32(offset+8),"respawns":data.decode_u32(offset+80) & 255,"gear":bool(flags & 16),"flaps":bool(flags & 32),"afterburner":bool(flags & 64),"airbrake":bool(flags & 128),"profile":(flags>>8) & 3,"rates":Vector3.ZERO}
  var rate_bits: int=data.decode_u32(offset+80)
  for j: int in 3:s.rates[j]=float(((rate_bits>>(8+j*8)) & 255)-128)/32.0
  if not s.p.is_finite() or not s.v.is_finite() or int(s.plane)>=AviaFlight.PLANES.size() or int(s.profile)>2:return {}
  for key: String in ["pitch","yaw","roll","health","distance"]:
   if not is_finite(float(s[key])):return {}
  result[int(data.decode_u32(offset))]={"state":s,"ack":data.decode_u32(offset+4),"race":{"next":data.decode_u32(offset+64),"start":data.decode_u32(offset+68),"time":data.decode_float(offset+72)},"score":data.decode_u32(offset+76)}
 return result
