package irish_integers

import "core:fmt"
import "core:c"
import "core:math/rand"
import "core:mem"
import mu "vendor:microui"
import mu_rl "micro_ui_raylib"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 1080
WINDOW_WIDTH :: 1920
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

board_rect := rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
square_length: f32 = BOARD_SIZE / 4

main :: proc() {
    using rl, mu_rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Irish Integers")
    defer CloseWindow()

    // microui
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }
    defer delete(pixels)

    image := rl.Image {
        data    = raw_data(pixels),
        width   = mu.DEFAULT_ATLAS_WIDTH,
        height  = mu.DEFAULT_ATLAS_HEIGHT,
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8A8,
    }
    ui_state.atlas_texture = rl.LoadTextureFromImage(image)
    defer rl.UnloadTexture(ui_state.atlas_texture)

    ctx := &ui_state.mu_ctx
    mu.init(ctx)
    ctx.text_width = rl_text_width
    ctx.text_height = rl_text_height
    ctx.style.spacing += 3

    SetTargetFPS(60)
    game := init_game()
    for !WindowShouldClose() {
        using game
        mu_input(ctx)
        if IsKeyPressed(.Q) do break
        if IsKeyPressed(.R) {
            mem.set(&game.board, 0, size_of(Cell_state) * 16)
            for number_piece in &game.number_pieces do number_piece.piece_state = .HIDDEN
            state = .NEW_PIECE
        }
        game_logic(&game, ctx)
        render_game(&game, ctx)
        free_all(context.temp_allocator)
    }
}

game_logic :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    mouse_position := GetMousePosition()

    mu.begin(ctx)
    defer mu.end(ctx)

    @(static)
    opts := mu.Options{.NO_FRAME, .NO_TITLE, .NO_INTERACT, .NO_RESIZE}

    if mu.window(
           ctx,
           "a series of buttons",
           mu.Rect{auto_cast board_rect.x - 190, auto_cast board_rect.y, 190, 100},
           opts,
       ) {
        mu.layout_row(ctx, {-1})
        // hidden -> flipped <-> in_hand -> on_board      
        //              ^                         /       
        //              \ _______________________/ (swap) 
        switch state {
        case .NEW_PIECE:
            if .SUBMIT in mu.button(ctx, "Flip a piece", .NONE, {}) {
                piece_in_hand = take_random_piece_in_hand(game.number_pieces[:], .HIDDEN)
                state = .PIECE_IN_HAND
            }

            if .SUBMIT in mu.button(ctx, "Take a known piece RNG", .NONE, {}) {
                //Take a random known piece
                total_flipped := 0
                for number_piece in number_pieces {
                    if number_piece.piece_state == .FLIPPED do total_flipped += 1
                }
                if total_flipped != 0 {
                    piece_in_hand = take_random_piece_in_hand(number_pieces[:], .FLIPPED)
                    state = .PIECE_IN_HAND
                } else do fmt.println("NO more flipped pieces")
            }

        case .PIECE_IN_HAND:
            one_cell_selected := false // only 1 cell to interact at a time
            mouse_in_ui := mu_rl.mouse_in_ui(ctx)
            //check collison with each cell
            loop: for i in 0 ..< 4 {
                for j in 0 ..< 4 {
                    if mouse_in_ui {
                        board[i][j].highlighted = false
                        continue
                    }
                    cell_rect := get_cell_rect({i, j})
                    collision := CheckCollisionPointRec(mouse_position, cell_rect)
                    if collision && IsMouseButtonUp(.LEFT) && !one_cell_selected {
                        board[i][j].highlighted = true
                        one_cell_selected = true
                    } else if collision && !IsMouseButtonUp(.LEFT) && !one_cell_selected {
                        using current_cell := &board[i][j]
                        highlighted = true
                        one_cell_selected = true
                        if number == 0 {
                            number = piece_in_hand.?.number
                            state = .NUMBER_PLACED
                            piece_in_hand.?.piece_state = .ON_BOARD
                            piece_in_hand = nil
                        } else {
                            // swapping pieces
                            state = .NUMBER_PLACED
                            number_pieces[board[i][j].number - 1].piece_state = .FLIPPED
                            board[i][j].number = piece_in_hand.?.number
                            piece_in_hand.?.piece_state = .ON_BOARD
                            piece_in_hand = nil
                        }
                    } else do board[i][j].highlighted = false
                }
            }
        case .NUMBER_PLACED:
            if IsMouseButtonReleased(.LEFT) do state = .NEW_PIECE
        }
    }
}

render_game :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(BLACK)
    origine := Vector2{board_rect.x, board_rect.y}
    // draw board_rect and line separators
    defer {
        // board_rect
        DrawRectangleLinesEx(board_rect, 6, RAYWHITE)
        // vertical
        for i in 0 ..< 3 {
            x: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {x, 0}
            end := origine + {x, board_rect.height}
            DrawLineEx(start, end, 3, RAYWHITE)
        }
        // horizontal
        for i in 0 ..< 3 {
            y: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {0, y}
            end := origine + {board_rect.width, y}
            DrawLineEx(start, end, 3, RAYWHITE)
        }
        // numbers
        for i in 0 ..< 4 {
            for j in 0 ..< 4 {
                draw_number_in_cell(&board, {i, j})
            }
        }
        mu_rl.render(ctx)
    }

    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
            using current_cell := board[i][j]
            if highlighted {
                cell_rect := get_cell_rect({i, j})
                DrawRectangleRec(cell_rect, GRAY)
            }
        }
    }
    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Number in hand:"),
        auto_cast (board_rect.x + board_rect.width + 50),
        auto_cast board_rect.y + 20,
        25,
        RAYWHITE,
    )

    piece_in_hand_ok, ok := piece_in_hand.?
    if ok {
        DrawText(
            fmt.ctprintf("%d", piece_in_hand_ok.number),
            auto_cast (board_rect.x + board_rect.width + 120),
            auto_cast board_rect.y + 59,
            FONT_SIZE,
            RAYWHITE,
        )
    }


    flipped_pieces_rect := board_rect
    flipped_pieces_rect.y -= 200
    flipped_pieces_rect.x -= 100
    new_square_length := flipped_pieces_rect.width / 10

    DrawText(
        fmt.ctprintf("Flipped Pieces:"),
        auto_cast flipped_pieces_rect.x,
        auto_cast flipped_pieces_rect.y - 75,
        FONT_SIZE - 20,
        RAYWHITE,
    )
    // render the flipped numbers
    for number_piece, index in number_pieces {
        if number_piece.piece_state == .FLIPPED {
            draw_number_in_square(
                number_piece.number,
                {index / 10, index % 10},
                flipped_pieces_rect,
                new_square_length,
                30,
            )
        }

    }


}

Game :: struct {
    state:         Game_state,
    piece_in_hand: Maybe(^Number_piece),
    board:         Board_matrix,
    number_pieces: [20]Number_piece,
}

Game_state :: enum {
    NEW_PIECE,
    PIECE_IN_HAND,
    NUMBER_PLACED,
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

Cell_state :: struct {
    number:      int,
    highlighted: bool,
}

// if number is zero -> no number in cell
Board_matrix :: distinct [4][4]Cell_state

// hidden -> flipped <-> in_hand -> on_board      
//              ^                         /       
//              \ _______________________/ (swap) 
Number_piece :: struct {
    piece_state: Piece_state,
    number:      int,
}

Piece_state :: enum {
    HIDDEN,
    FLIPPED, // known but not in hand  
    IN_HAND,
    ON_BOARD,
}
init_game :: proc() -> Game {
    game: Game
    for i in 1 ..= 20 {
        game.number_pieces[i - 1].number = i
    }

    when ODIN_DEBUG {
        game.number_pieces[0].piece_state = .FLIPPED
        game.number_pieces[1].piece_state = .FLIPPED
        game.number_pieces[2].piece_state = .FLIPPED
    }
    return game
}

draw_number_in_cell :: proc(
    board: ^Board_matrix,
    cell_coords: [2]int,
    board_rect: rl.Rectangle = board_rect,
    square_length: f32 = square_length,
) {
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    number := board[cell_coords.x][cell_coords.y].number
    assert(number <= 20 && number >= 0)
    // don't draw if cell is empty
    if number == 0 do return
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, FONT_SIZE, FONT_SPACING)
    box_rect := get_cell_rect(cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(square_length - measure.x) / 2, (square_length - measure.y) / 2 + 5},
        FONT_SIZE,
        FONT_SPACING,
        RAYWHITE,
    )
}

draw_number_in_square :: proc(
    number: int,
    cell_coords: [2]int,
    rect: rl.Rectangle,
    square_length: f32,
    font_size: f32,
) {
    if number == 0 do return
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, FONT_SIZE, FONT_SPACING)
    box_rect := get_cell_rect(cell_coords, rect, square_length)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(square_length - measure.x) / 2, (square_length - measure.y) / 2 + 5},
        font_size,
        FONT_SPACING,
        RAYWHITE,
    )
}

take_random_piece_in_hand :: proc(number_pieces: []Number_piece, piece_type_to_take: Piece_state) -> ^Number_piece {
    indices_of_pieces_of_interest := make([dynamic]int, context.temp_allocator)

    number_pieces := number_pieces
    for number_piece, i in number_pieces {
        using number_piece
        if piece_state == piece_type_to_take {
            append(&indices_of_pieces_of_interest, i)
        }
    }
    assert(len(indices_of_pieces_of_interest) > 0)

    index_of_piece_to_flip := rand.choice(indices_of_pieces_of_interest[:])
    number_pieces[index_of_piece_to_flip].piece_state = .IN_HAND
    return &number_pieces[index_of_piece_to_flip]
}

random_number :: #force_inline proc(lo := 1, hi := 20, r: ^rand.Rand = nil) -> int {
    number_float := rand.float64_range(1, 20)
    return int(number_float + 0.5)
}

get_cell_rect :: proc(cell_coords: [2]int, board_rect := board_rect, square_length := square_length) -> rl.Rectangle {
    return(
        rl.Rectangle{
            x = board_rect.x + square_length * auto_cast cell_coords.y,
            y = board_rect.y + square_length * auto_cast cell_coords.x,
            width = square_length,
            height = square_length,
        } \
    )
}
