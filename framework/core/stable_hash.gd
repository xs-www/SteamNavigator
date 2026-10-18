class_name StableHash
extends RefCounted
## Version-independent hashing helpers.
##
## Godot's built-in hash() may change between engine versions. Named RNG
## streams and state fingerprints must stay stable across engine upgrades, so
## this module owns a small, documented FNV-1a implementation instead.


static func fnv1a_32(text: String) -> int:
	var value: int = 0x811C9DC5
	for byte in text.to_utf8_buffer():
		value = value ^ int(byte)
		value = (value * 0x01000193) & 0xFFFFFFFF
	return value & 0xFFFFFFFF


static func combine(parts: PackedStringArray) -> int:
	return fnv1a_32("|".join(parts))


## Derives a positive 63-bit seed for a named random stream.
## Adding a new stream must not perturb the output of any other stream.
static func seed_from(base_seed: int, stream: StringName, context_key: String = "") -> int:
	var material := "%d|%s|%s" % [base_seed, String(stream), context_key]
	var stream_hash := fnv1a_32(material)
	var mixed := (base_seed ^ (stream_hash << 16) ^ stream_hash) & 0x7FFFFFFFFFFFFFFF
	return mixed if mixed != 0 else 1
