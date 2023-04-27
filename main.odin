package lucky_numbers

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
    using rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT, .WINDOW_HIGHDPI})
    InitWindow(1200, 700, "lul")
    defer CloseWindow()

    camera: Camera2D
    SetTargetFPS(60)
    for !WindowShouldClose() {
	BeginDrawing()
	defer EndDrawing()
	
	ClearBackground(RAYWHITE)
	Board := rl.Rectangle{0,0,500,500}
	DrawRectangleLinesEx(Board,10,BLACK)
    }
}
