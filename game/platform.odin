package game

update_and_render_proc :: proc()
get_sound_samples_proc :: proc()

Align16 :: proc(Value: u32) -> u32 {
	return (Value + u32(15)) & ~u32(15)
}
