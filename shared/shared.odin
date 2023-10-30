package hm_shared

update_and_render_proc :: proc()
get_sound_samples_proc :: proc()

Kilobytes :: proc(val: int) -> int {
	return val * 1024
}

Megabytes :: proc(val: int) -> int {
	return Kilobytes(val) * 1024
}

Gigabytes :: proc(val: int) -> int {
	return Megabytes(val) * 1024
}

Terabytes :: proc(val: int) -> int {
	return Gigabytes(val) * 1024
}

Align16 :: proc(Value: u32) -> u32 {
	return (Value + u32(15)) & ~u32(15)
}

DEBUGReadFileResult :: struct {
	ContentsSize: u32,
	Contents:     rawptr,
}

debug_free_file_memory_proc :: proc(Memory: rawptr)
debug_read_entire_file_proc :: proc(Filename: string) -> DEBUGReadFileResult
debug_write_entire_file_proc :: proc(Filename: string, MemorySize: u32, Memory: rawptr) -> b8

GameMemory :: struct {
	PermanentStorageSize:         int,
	PermanentStorage:             rawptr,
	TransientStorageSize:         int,
	TransientStorage:             rawptr,
	DEBUGPlatformFreeFileMemory:  debug_free_file_memory_proc,
	DEBUGPlatformReadEntireFile:  debug_read_entire_file_proc,
	DEBUGPlatformWriteEntireFile: debug_write_entire_file_proc,
}
