package app

import game "../game"
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

	SoundOutput :: struct {
		SamplesPerSecond:    i32,
		RunningSampleIndex:  u32,
		BytesPerSample:      i32,
		SecondaryBufferSize: u32,
		SafetyBytes:         u32,
	}

	DebugTimeMarker :: struct {
		QueuedAudioBytes:       u32,
		OutputByteCount:        u32,
		ExpectedBytesUntilFlip: u32,
	}

	GameCode :: struct {
		GameCodeDLL:      rawptr,
		DLLLastWriteTime: os.File_Time,
		UpdateAndRender:  game.update_and_render_proc,
		GetSoundSamples:  game.get_sound_samples_proc,
		IsValid:          b8,
	}

	STATE_FILE_NAME_COUNT :: 4096
	ReplayBuffer :: struct {
		FileHandle:  os.Handle,
		MemoryMap:   rawptr,
		FileName:    string,
		MemoryBlock: rawptr,
	}

	AppState :: struct {
		TotalSize:           u64,
		GameMemoryBlock:     rawptr,
		ReplayBuffers:       [4]ReplayBuffer,
		RecordingHandle:     i32,
		InputRecordingIndex: i32,
		PlaybackHandle:      i32,
		InputPlayingIndex:   i32,
		BasePath:            string,
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
		Buffer.Pitch = i32(game.Align16(u32(Width * BytesPerPixel)))
		BitmapMemorySize := uint(Buffer.Pitch * Buffer.Height)
		Buffer.Memory = win32.VirtualAlloc(
			nil,
			BitmapMemorySize,
			win32.MEM_RESERVE | win32.MEM_COMMIT,
			win32.PAGE_READWRITE,
		)
	}

	main :: proc() {
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
			}
		}
	}
}
