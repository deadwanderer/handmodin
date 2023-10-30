package app

import s "../shared"
import "core:fmt"
import "core:os"
import "core:strings"
import win32 "core:sys/windows"
import sdl "vendor:sdl2"

HANDMADE_INTERNAL :: #config(HANDMADE_INTERNAL, true)
HANDMADE_SLOW :: #config(HANDMADE_SLOW, true)
HANDMADE_SDL :: #config(HANDMADE_SDL, true)
HANDMADE_WINDOWS :: #config(HANDMADE_WINDOWS, false)
HANDMADE_LINUX :: #config(HANDMADE_LINUX, false)

when HANDMADE_SDL {

	OffscreenBuffer :: struct {
		Texture:       ^sdl.Texture,
		Memory:        rawptr,
		Width:         i32,
		Height:        i32,
		Pitch:         i32,
		BytesPerPixel: i32,
	}

	WindowDimension :: struct {
		Width:  i32,
		Height: i32,
	}

	// SoundOutput :: struct {
	// 	SamplesPerSecond:    i32,
	// 	RunningSampleIndex:  u32,
	// 	BytesPerSample:      i32,
	// 	SecondaryBufferSize: u32,
	// 	SafetyBytes:         u32,
	// }

	// DebugTimeMarker :: struct {
	// 	QueuedAudioBytes:       u32,
	// 	OutputByteCount:        u32,
	// 	ExpectedBytesUntilFlip: u32,
	// }

	GameCode :: struct {
		GameCodeDLL:      rawptr,
		DLLLastWriteTime: os.File_Time,
		UpdateAndRender:  s.update_and_render_proc,
		GetSoundSamples:  s.get_sound_samples_proc,
		IsValid:          b8,
	}

	STATE_FILE_NAME_COUNT :: 4096
	// ReplayBuffer :: struct {
	// 	FileHandle:  os.Handle,
	// 	MemoryMap:   rawptr,
	// 	FileName:    string,
	// 	MemoryBlock: rawptr,
	// }

	AppState :: struct {
		TotalSize:       u64,
		GameMemoryBlock: rawptr,
		// ReplayBuffers:       [4]ReplayBuffer,
		// RecordingHandle:     i32,
		// InputRecordingIndex: i32,
		// PlaybackHandle:      i32,
		// InputPlayingIndex:   i32,
		BasePath:        string,
	}

	GlobalRunning: b8 = false
	GlobalPause: b8 = false
	GlobalBackbuffer: OffscreenBuffer
	GlobalPerfCountFrequency: u64
	DEBUGGlobalShowCursor: b8 = false


	MAX_CONTROLLERS :: 4
	CONTROLLER_AXIS_LEFT_DEADZONE :: 7849

	ControllerHandles: [MAX_CONTROLLERS]^sdl.GameController
	RumbleHandles: [MAX_CONTROLLERS]^sdl.Haptic

	GetEXEFileName :: proc(State: ^AppState) {
		State.BasePath = string(sdl.GetBasePath())
	}

	BuildEXEPathFileName :: proc(State: ^AppState, FileName: string) -> string {
		sb: strings.Builder
		strings.builder_make(STATE_FILE_NAME_COUNT)
		fmt.sbprintf(&sb, "%s%s", State.BasePath, FileName)
		return strings.to_string(sb)
	}

	DEBUGPlatformFreeFileMemory :: proc(Memory: rawptr) {
		if Memory != nil {
			win32.VirtualFree(Memory, 0, win32.MEM_RELEASE)
		}
	}

	DEBUGPlatformReadEntireFile :: proc(Filename: string) -> s.DEBUGReadFileResult {
		Result: s.DEBUGReadFileResult = {}

		FileHandle: win32.HANDLE = win32.CreateFileA(
			strings.clone_to_cstring(Filename, context.temp_allocator),
			win32.GENERIC_READ,
			win32.FILE_SHARE_READ,
			nil,
			win32.OPEN_EXISTING,
			0,
			nil,
		)
		if FileHandle != win32.INVALID_HANDLE_VALUE {
			FileSize: win32.LARGE_INTEGER
			if win32.GetFileSizeEx(FileHandle, &FileSize) == true {
				FileSize32 := u32(FileSize)
				Result.Contents = win32.VirtualAlloc(
					nil,
					uint(FileSize32),
					win32.MEM_RESERVE | win32.MEM_COMMIT,
					win32.PAGE_READWRITE,
				)
				if Result.Contents != nil {
					BytesRead: win32.DWORD
					if win32.ReadFile(FileHandle, Result.Contents, FileSize32, &BytesRead, nil) &&
					   FileSize32 == BytesRead {
						Result.ContentsSize = FileSize32
					} else {
						DEBUGPlatformFreeFileMemory(Result.Contents)
						Result.Contents = nil
					}
				} else {}
			} else {}

			win32.CloseHandle(FileHandle)
		} else {}

		return Result
	}

	DEBUGPlatformWriteEntireFile :: proc(Filename: string, MemorySize: u32, Memory: rawptr) -> b8 {
		Result: b8 = false
		FileHandle: win32.HANDLE = win32.CreateFileA(
			strings.clone_to_cstring(Filename, context.temp_allocator),
			win32.GENERIC_WRITE,
			0,
			nil,
			win32.CREATE_ALWAYS,
			0,
			nil,
		)
		if FileHandle != win32.INVALID_HANDLE_VALUE {
			BytesWritten: win32.DWORD
			if win32.WriteFile(FileHandle, Memory, MemorySize, &BytesWritten, nil) == true {
				Result = BytesWritten == MemorySize
			} else {

			}

			win32.CloseHandle(FileHandle)
		} else {

		}

		return Result
	}

	GetLastWriteTime :: proc(Filename: string) -> os.File_Time {
		Result, err := os.last_write_time_by_name(Filename)
		if err != os.ERROR_NONE {
			return os.File_Time(0)
		}
		return Result
	}

	LoadGameCode :: proc(SourceDLLName, TempDLLName: string) -> GameCode {
		Result: GameCode = {}

	}

	OpenGameControllers :: proc() {
		for i in 0 ..< MAX_CONTROLLERS {
			ControllerHandles[i] = nil
			RumbleHandles[i] = nil
		}

		MaxJoysticks := sdl.NumJoysticks()
		ControllerIndex: int = 0
		for JoystickIndex in 0 ..< MaxJoysticks {
			if !sdl.IsGameController(JoystickIndex) {
				continue
			}
			if ControllerIndex >= MAX_CONTROLLERS {
				break
			}
			ControllerHandles[ControllerIndex] = sdl.GameControllerOpen(JoystickIndex)
			JoystickHandle := sdl.GameControllerGetJoystick(ControllerHandles[ControllerIndex])
			RumbleHandles[ControllerIndex] = sdl.HapticOpenFromJoystick(JoystickHandle)
			if sdl.HapticRumbleInit(RumbleHandles[ControllerIndex]) != 0 {
				sdl.HapticClose(RumbleHandles[ControllerIndex])
				RumbleHandles[ControllerIndex] = nil
			}
			ControllerIndex += 1
		}
	}

	CloseGameControllers :: proc() {
		for ControllerIndex in 0 ..< MAX_CONTROLLERS {
			if ControllerHandles[ControllerIndex] != nil {
				if RumbleHandles[ControllerIndex] != nil {
					sdl.HapticClose(RumbleHandles[ControllerIndex])
					RumbleHandles[ControllerIndex] = nil
				}
				sdl.GameControllerClose(ControllerHandles[ControllerIndex])
				ControllerHandles[ControllerIndex] = nil
			}
		}
	}

	ResizeTexture :: proc(Buffer: ^OffscreenBuffer, Renderer: ^sdl.Renderer, Width, Height: i32) {
		if Buffer.Memory != nil {
			win32.VirtualFree(Buffer.Memory, 0, win32.MEM_RELEASE)
		}

		Buffer.Width = Width
		Buffer.Height = Height

		BytesPerPixel: i32 = 4
		Buffer.BytesPerPixel = BytesPerPixel

		if Buffer.Texture != nil {
			sdl.DestroyTexture(Buffer.Texture)
		}
		Buffer.Texture = sdl.CreateTexture(
			Renderer,
			u32(sdl.PixelFormatEnum.ARGB8888),
			.STREAMING,
			Buffer.Width,
			Buffer.Height,
		)
		Buffer.Pitch = i32(s.Align16(u32(Width * BytesPerPixel)))
		BitmapMemorySize := uint(Buffer.Pitch * Buffer.Height)
		Buffer.Memory = win32.VirtualAlloc(
			nil,
			BitmapMemorySize,
			win32.MEM_RESERVE | win32.MEM_COMMIT,
			win32.PAGE_READWRITE,
		)
	}


	ProcessKeyboardEvent :: proc(NewState: ^s.GameButtonState, IsDown: b8) {
		if NewState.EndedDown != IsDown {
			NewState.EndedDown = IsDown
			NewState.HalfTransitionCount += 1
		}
	}

	ProcessGameControllerButton :: proc(
		OldState: ^s.GameButtonState,
		Value: b8,
		NewState: ^s.GameButtonState,
	) {
		NewState.EndedDown = Value
		NewState.HalfTransitionCount = 1 if OldState.EndedDown != NewState.EndedDown else 0
	}

	ProcessGameControllerAxisValue :: proc(Value: i16, DeadZoneThreshold: i16) -> f32 {
		Result: f32 = 0.0

		if Value < -DeadZoneThreshold {
			Result = f32(Value + DeadZoneThreshold) / (32768.0 - f32(DeadZoneThreshold))
		} else if Value > DeadZoneThreshold {
			Result = f32(Value - DeadZoneThreshold) / (32767.0 - f32(DeadZoneThreshold))
		}
		return Result
	}

	ToggleFullscreen :: proc(Window: ^sdl.Window) {
		Flags := sdl.GetWindowFlags(Window)
		if u32(sdl.WINDOW_FULLSCREEN) & Flags == 1 {
			sdl.SetWindowFullscreen(Window, {})
		} else {
			sdl.SetWindowFullscreen(Window, sdl.WINDOW_FULLSCREEN)
		}
	}

	ProcessPendingEvents :: proc(State: ^AppState, KeyboardController: ^s.GameControllerInput) {
		Event: sdl.Event
		for sdl.PollEvent(&Event) {
			#partial switch Event.type {
			case .QUIT:
				{
					GlobalRunning = false
				}
			case .KEYDOWN, .KEYUP:
				{
					KeyCode := Event.key.keysym.sym
					IsDown := Event.key.state == sdl.PRESSED

					if Event.key.repeat == 0 {
						if KeyCode == .w {
							ProcessKeyboardEvent(&KeyboardController.MoveUp, IsDown)
						}
					}
				}
			}
		}
	}

	GetWallClock :: #force_inline proc() -> u64 {
		return sdl.GetPerformanceCounter()
	}

	GetSecondsElapsed :: proc(Start, End: u64) -> f32 {
		return f32(End - Start) / f32(GlobalPerfCountFrequency)
	}

	main :: proc() {
		fmt.println("Hello, Handmade SDL")
		State: AppState = {}

		GlobalPerfCountFrequency = sdl.GetPerformanceFrequency()

		GetEXEFileName(&State)

		SourceGameCodeDLLFullPath := BuildEXEPathFileName(&State, "handmade.dll")
		TempGameCodeDLLFullPath := BuildEXEPathFileName(&State, "handmade_temp.dll")
		GameCodeLockFullPath := BuildEXEPathFileName(&State, "lock.tmp")

		sdl.Init({.VIDEO, .GAMECONTROLLER, .HAPTIC, .AUDIO})

		OpenGameControllers()

		when HANDMADE_INTERNAL {
			DEBUGGlobalShowCursor = true
		}

		// Create the window
		Window: ^sdl.Window = sdl.CreateWindow(
			"HandmOdin",
			sdl.WINDOWPOS_CENTERED,
			sdl.WINDOWPOS_CENTERED,
			1280,
			720,
			{.RESIZABLE},
		)

		if Window != nil {
			sdl.ShowCursor(sdl.ENABLE if DEBUGGlobalShowCursor else sdl.DISABLE)

			Renderer: ^sdl.Renderer = sdl.CreateRenderer(Window, -1, {.PRESENTVSYNC})
			if Renderer != nil {
				ResizeTexture(&GlobalBackbuffer, Renderer, 1280, 720)

				GlobalRunning = true

				for GlobalRunning {
					BaseAddress: rawptr =
						rawptr(uintptr(s.Terabytes(2))) when HANDMADE_INTERNAL else 0

					GameMem: s.GameMemory = {}
					GameMem.PermanentStorageSize = s.Megabytes(256)
					GameMem.TransientStorageSize = s.Gigabytes(1)
					GameMem.DEBUGPlatformFreeFileMemory = DEBUGPlatformFreeFileMemory
					GameMem.DEBUGPlatformReadEntireFile = DEBUGPlatformReadEntireFile
					GameMem.DEBUGPlatformWriteEntireFile = DEBUGPlatformWriteEntireFile

					State.TotalSize = u64(
						GameMem.PermanentStorageSize + GameMem.TransientStorageSize,
					)
					State.GameMemoryBlock = win32.VirtualAlloc(
						BaseAddress,
						uint(State.TotalSize),
						win32.MEM_RESERVE | win32.MEM_COMMIT,
						win32.PAGE_READWRITE,
					)
					GameMem.PermanentStorage = State.GameMemoryBlock
					GameMem.TransientStorage = rawptr(
						uintptr(GameMem.PermanentStorage) + uintptr(GameMem.PermanentStorageSize),
					)

					if GameMem.PermanentStorage != nil && GameMem.TransientStorage != nil {
						Input: [2]s.GameInput = {}
						NewInput: ^s.GameInput = &Input[0]
						OldInput: ^s.GameInput = &Input[1]

						LastCounter := GetWallClock()
						FlipWallClock := GetWallClock()
					}
				}
			}
		}
	}
}
