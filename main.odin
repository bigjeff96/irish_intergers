package lucky_numbers

import "core:fmt"
import rl "vendor:raylib"
import "core:c"

WINDOW_HEIGHT :: 700
WINDOW_WIDTH :: 1200
FONT_SIZE :: 69
BOARD_SIZE :: 500

main :: proc() {
    using rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "lul")
    defer CloseWindow()

    SetTargetFPS(60)
    for !WindowShouldClose() {
        if IsKeyPressed(.Q) do break
        render_game()
    }
}

render_game :: proc() {
    using rl
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(RAYWHITE)

    board := rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
    DrawRectangleLinesEx(board, 6, BLACK)
    // draw line separators
    square_length := BOARD_SIZE / 4
    origine := Vector2{board.x, board.y}
    // vertical
    for i in 0 ..< 3 {
        x: f32 = auto_cast square_length * auto_cast (i + 1)
        start := origine + {x, 0}
        end := origine + {x, board.height}
        DrawLineEx(start, end, 3, BLACK)
    }
    // horizontal
    for i in 0 ..< 3 {
        y: f32 = auto_cast square_length * (auto_cast i + 1)
        start := origine + {0, y}
        end := origine + {board.width, y}
        DrawLineEx(start, end, 3, BLACK)
    }

    // draw number
    DrawText(
        fmt.ctprintf("15"),
        auto_cast (25 + origine.x + board.width / 2),
        auto_cast (30 + origine.y + board.height / 2),
        FONT_SIZE,
        BLACK,
    )
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

Board_matrix :: distinct [4][4]int

rect_float_to_int :: #force_inline proc(rect: rl.Rectangle) -> Rectangle_cint {
    return(
        Rectangle_cint{
            x = auto_cast rect.x,
            y = auto_cast rect.y,
            width = auto_cast rect.width,
            height = auto_cast rect.height,
        } \
    )
}
