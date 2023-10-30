package hm_shared

update_and_render_proc :: proc(
	Memory: ^GameMemory,
	Input: ^GameInput,
	Buffer: ^GameOffscreenBuffer,
)

get_sound_samples_proc :: proc(Memory: ^GameMemory, SoundBuffer: ^GameSoundOutputBuffer)

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

BITMAP_BYTES_PER_PIXEL :: 4

GameOffscreenBuffer :: struct {
	Memory: rawptr,
	Width:  int,
	Height: int,
	Pitch:  int,
}

GameSoundOutputBuffer :: struct {
	SamplesPerSecond: int,
	SampleCount:      int,
	Samples:          []i16,
}

GameButtonState :: struct {
	HalfTransitionCount: int,
	EndedDown:           b8,
}

GameControllerInput :: struct {
	IsConnected:   b8,
	IsAnalog:      b8,
	StickAverageX: f32,
	StickAverageY: f32,
	using _:       struct #raw_union {
		Buttons: [12]GameButtonState,
		using _: struct {
			MoveUp:        GameButtonState,
			MoveDown:      GameButtonState,
			MoveLeft:      GameButtonState,
			MoveRight:     GameButtonState,
			ActionUp:      GameButtonState,
			ActionDown:    GameButtonState,
			ActionLeft:    GameButtonState,
			ActionRight:   GameButtonState,
			LeftShoulder:  GameButtonState,
			RightShoulder: GameButtonState,
			Back:          GameButtonState,
			Start:         GameButtonState,
		},
	},
}

GameInput :: struct {
	MouseButtons:           [5]GameButtonState,
	MouseX, MouseY, MouseZ: i32,
	ExecutableReloaded:     b8,
	dtForFrame:             f32,
	Controllers:            [5]GameControllerInput,
}


GameMemory :: struct {
	IsInitialized:                b8,
	PermanentStorageSize:         int,
	PermanentStorage:             rawptr,
	TransientStorageSize:         int,
	TransientStorage:             rawptr,
	DEBUGPlatformFreeFileMemory:  debug_free_file_memory_proc,
	DEBUGPlatformReadEntireFile:  debug_read_entire_file_proc,
	DEBUGPlatformWriteEntireFile: debug_write_entire_file_proc,
}

GetController :: #force_inline proc(
	Input: ^GameInput,
	ControllerIndex: uint,
) -> ^GameControllerInput {
	assert(ControllerIndex < len(Input.Controllers))

	return &Input.Controllers[ControllerIndex]
}
