package main

import "core:sys/windows"
// import "vendor:sdl2"

main :: proc() {
	message_title := "This is Handmodin"
	windows.MessageBoxW(
		nil,
		windows.utf8_to_wstring(message_title),
		windows.utf8_to_wstring("Handmade Odin"),
		windows.MB_OK | windows.MB_ICONINFORMATION,
	)
}
