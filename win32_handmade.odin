package main

import "core:fmt"
// import "core:mem"
import "core:runtime"
import win32 "core:sys/windows"
// _ :: win32
// import "vendor:sdl2"

GlobalRunning: bool
BitmapInfo: win32.BITMAPINFO
BitmapMemory: [dynamic]u32
BitmapWidth: i32
BitmapHeight: i32
BytesPerPixel: i32 : 4

InitialWindowWidth :: 1280
InitialWindowHeight :: 720

render_weird_gradient :: proc(Bitmap: []u32, BlueOffset: i32, GreenOffset: i32) {
	for Y: i32 = 0; Y < BitmapHeight; Y += 1 {
		for X: i32 = 0; X < BitmapWidth; X += 1 {
			Blue: u8 = cast(u8)(X + BlueOffset)
			Green: u8 = cast(u8)(Y + GreenOffset)

			Bitmap[Y * BitmapWidth + X] = ((cast(u32)Green << 8) | cast(u32)Blue)
		}
	}
}

win32_resize_dib_section :: proc(width: i32, height: i32) {
	delete(BitmapMemory)

	BitmapWidth = width
	BitmapHeight = height

	BitmapInfo.bmiHeader.biSize = size_of(BitmapInfo.bmiHeader)
	BitmapInfo.bmiHeader.biWidth = BitmapWidth
	BitmapInfo.bmiHeader.biHeight = -BitmapHeight
	BitmapInfo.bmiHeader.biPlanes = 1
	BitmapInfo.bmiHeader.biBitCount = 32
	BitmapInfo.bmiHeader.biCompression = win32.BI_RGB

	BitmapMemorySize := (BitmapWidth * BitmapHeight)
	BitmapMemory = make([dynamic]u32, BitmapMemorySize)
}

win32_update_window :: proc(
	DeviceContext: win32.HDC,
	ClientRect: ^win32.RECT,
	X: i32,
	Y: i32,
	Width: i32,
	Height: i32,
) {
	WindowWidth := ClientRect.right - ClientRect.left
	WindowHeight := ClientRect.bottom - ClientRect.top
	win32.StretchDIBits(
		DeviceContext,
		// X,
		// Y,
		// Width,
		// Height,
		// X,
		// Y,
		// Width,
		// Height,
		0,
		0,
		BitmapWidth,
		BitmapHeight,
		0,
		0,
		WindowWidth,
		WindowHeight,
		raw_data(BitmapMemory),
		&BitmapInfo,
		win32.DIB_RGB_COLORS,
		win32.SRCCOPY,
	)
}

win32_main_window_callback :: proc "stdcall" (
	window: win32.HWND,
	message: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
) -> win32.LRESULT {
	context = runtime.default_context()
	Result: win32.LRESULT = 0

	switch (message) {
	case win32.WM_SIZE:
		ClientRect: win32.RECT
		win32.GetClientRect(window, &ClientRect)
		Width := ClientRect.right - ClientRect.left
		Height := ClientRect.bottom - ClientRect.top
		win32_resize_dib_section(Width, Height)
		fmt.println("WM_SIZE")
	case win32.WM_CLOSE:
		fmt.println("WM_CLOSE")
		GlobalRunning = false
	case win32.WM_DESTROY:
		fmt.println("WM_DESTROY")
		GlobalRunning = false
	case win32.WM_ACTIVATEAPP:
		fmt.println("WM_ACTIVATEAPP")
	case win32.WM_PAINT:
		Paint: win32.PAINTSTRUCT
		DeviceContext := win32.BeginPaint(window, &Paint)
		X := Paint.rcPaint.left
		Y := Paint.rcPaint.top
		Width := Paint.rcPaint.right - Paint.rcPaint.left
		Height := Paint.rcPaint.bottom - Paint.rcPaint.top

		ClientRect: win32.RECT
		win32.GetClientRect(window, &ClientRect)

		win32_update_window(DeviceContext, &ClientRect, X, Y, Width, Height)
	case:
		Result = win32.DefWindowProcW(window, message, wparam, lparam)
	}
	return Result
}

main :: proc() {
	GlobalRunning = false

	Instance := win32.HANDLE(win32.GetModuleHandleA(nil))
	WindowClass := win32.WNDCLASSW {
		style         = 0,
		lpfnWndProc   = win32_main_window_callback,
		hInstance     = Instance,
		hIcon         = win32.LoadIconA(nil, win32.IDI_APPLICATION),
		hCursor       = win32.LoadCursorA(nil, win32.IDC_ARROW),
		lpszClassName = win32.utf8_to_wstring("HandmOdin"),
	}
	if win32.RegisterClassW(&WindowClass) != 0 {
		Window := win32.CreateWindowExW(
			0,
			WindowClass.lpszClassName,
			win32.utf8_to_wstring("Handmade Odin"),
			win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
			win32.CW_USEDEFAULT,
			win32.CW_USEDEFAULT,
			InitialWindowWidth,
			InitialWindowHeight,
			nil,
			nil,
			Instance,
			nil,
		)

		if Window != nil {
			XOffset: i32 = 0
			YOffset: i32 = 0

			BitmapMemorySize := (InitialWindowWidth * InitialWindowHeight)
			BitmapMemory = make([dynamic]u32, BitmapMemorySize)
			GlobalRunning = true
			for GlobalRunning {
				Message: win32.MSG
				for win32.PeekMessageW(&Message, nil, 0, 0, win32.PM_REMOVE) {
					if Message.message == win32.WM_QUIT {
						GlobalRunning = false
					}
					win32.TranslateMessage(&Message)
					win32.DispatchMessageW(&Message)
				}

				render_weird_gradient(BitmapMemory[:], XOffset, YOffset)

				DeviceContext := win32.GetDC(Window)

				ClientRect: win32.RECT
				win32.GetClientRect(Window, &ClientRect)
				Width := ClientRect.right - ClientRect.left
				Height := ClientRect.bottom - ClientRect.top
				win32_update_window(DeviceContext, &ClientRect, 0, 0, Width, Height)
				win32.ReleaseDC(Window, DeviceContext)

				XOffset += 1
				YOffset += 2
			}
			win32.DestroyWindow(Window)
		} else {}
	} else {}
}
