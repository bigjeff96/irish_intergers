package irish_integers

WINDOW_HEIGHT :: 1080
WINDOW_WIDTH :: 1920
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

Game :: struct {
    state:             Game_state,
    piece_in_hand:     Maybe(^Number_piece),
    board:             Board_matrix,
    flipped_board:     Board_matrix,
    number_pieces:     [20]Number_piece,
    next_flipped_cell: int,
    highlight_logic:   struct {
        board_type: Board_type,
        cell_coord: [2]int,
    },
}

Game_state :: enum {
    NEW_PIECE,
    PIECE_IN_HAND,
    NUMBER_PLACED,
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

// if number is zero -> no number in cell
Board_matrix :: struct {
    rows:          int,
    columns:       int,
    rect:          rl.Rectangle,
    square_length: f32,
}

// hidden -> flipped <-> in_hand -> on_board      
//              ^                         /       
//              \ _______________________/ (swap) 
Number_piece :: struct {
    piece_state: Piece_state,
    number:      int,
    cell_coords: [2]int,
}

Piece_state :: enum {
    HIDDEN,
    FLIPPED, // known but not in hand  
    IN_HAND,
    ON_BOARD,
}

Board_type :: enum {
    NONE,
    BOARD,
    FLIPPED,
}

game_logic :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    mouse_position := GetMousePosition()

    mu.begin(ctx)
    defer mu.end(ctx)

    @(static)
    opts := mu.Options{.NO_FRAME, .NO_TITLE, .NO_INTERACT, .NO_RESIZE, .NO_SCROLL}

    numbers_on_board := get_numbers_on_board(game)

    if mu.window(
           ctx,
           "a series of buttons",
           mu.Rect{auto_cast board.rect.x + 550, auto_cast board.rect.y + 125, 320, 100},
           opts,
       ) {
        mu.layout_row(ctx, {-1}, 30) // 30 for good height of the buttons
        // hidden -> flipped <-> in_hand -> on_board      
        //              ^                         /       
        //              \ _______________________/ (swap) 
        switch state {
        case .NEW_PIECE:
            if .SUBMIT in mu.button(ctx, "Flip a piece", .NONE, {}) {
                piece_in_hand = take_random_piece_in_hand(game.number_pieces[:], .HIDDEN)
                state = .PIECE_IN_HAND
		highlight_logic.board_type = .NONE
		break
            }

	    highlight_logic.board_type = .NONE
	    mouse_position := GetMousePosition()
	    mouse_in_ui := mu_rl.mouse_in_ui(ctx)
	    mouse_on_flipped_board := CheckCollisionPointRec(mouse_position, flipped_board.rect)

	    using flipped_board
	    loop_flipped: for i in 0..<rows {
		for j in 0..<columns {
		    if mouse_in_ui || !mouse_on_flipped_board {
                        highlight_logic.board_type = .NONE
                        break loop_flipped
                    }
		    cell_rect := get_cell_rect(flipped_board, {i,j})
		    collision := CheckCollisionPointRec(mouse_position, cell_rect)

		    if collision && IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .FLIPPED
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                    } else if collision && !IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .FLIPPED
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
			number_in_cell, ok := check_if_number_in_cell(number_pieces[:], {i,j})
                        if !ok {
                            state = .NEW_PIECE
                        } else {
                            // swapping pieces
                            piece_in_hand = &number_pieces[number_in_cell - 1]
                            piece_in_hand.?.piece_state = .IN_HAND
                            state = .PIECE_IN_HAND
                        }
                    }
		}
	    }

        case .PIECE_IN_HAND:
            if .SUBMIT in mu.button(ctx, "Leave the piece", .NONE, {}) {
                piece_in_hand.?.piece_state = .FLIPPED
                number := piece_in_hand.?.number
                /* flipped_board.cells[number - 1].number = number */
                state = .NEW_PIECE
                piece_in_hand = nil
                return
            }

	    highlight_logic.board_type = .NONE
            mouse_in_ui := mu_rl.mouse_in_ui(ctx)
            mouse_on_board := CheckCollisionPointRec(mouse_position, board.rect)
            //check collision with each cell
            loop_board: for i in 0 ..< board.rows {
                for j in 0 ..< board.columns {
                    if mouse_in_ui || !mouse_on_board {
                        highlight_logic.board_type = .NONE
                        break loop_board
                    }
                    cell_rect := get_cell_rect(board, {i, j})
                    collision := CheckCollisionPointRec(mouse_position, cell_rect)

                    if collision && IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .BOARD
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                    } else if collision && !IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .BOARD
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                        number := numbers_on_board[i + board.rows * j]
                        if number == 0 {
			    // placing piece ob empty cell
                            piece_in_hand.?.piece_state = .ON_BOARD
                            piece_in_hand.?.cell_coords = {i, j}
                            piece_in_hand = nil
                            state = .NUMBER_PLACED
                        } else {
                            // swapping pieces
                            number_pieces[number - 1].piece_state = .FLIPPED
                            piece_in_hand.?.piece_state = .ON_BOARD
			    piece_in_hand.?.cell_coords = {i,j}
                            piece_in_hand = nil
                            state = .NUMBER_PLACED
                        }
                    }
                }
            }
        case .NUMBER_PLACED:
            if IsMouseButtonReleased(.LEFT) do state = .NEW_PIECE
        }
    }

    check_if_number_in_cell :: proc(number_pieces: []Number_piece, cell_coords: [2]int) -> (number: int, ok: bool) {
	i,j := expand_values(cell_coords)
	number = 10*i + j + 1
	if number_pieces[number - 1].piece_state == .FLIPPED {
	    ok = true
	    return
	} else do return
    }
}

render_game :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    BeginDrawing()
    defer EndDrawing()
    fmt.printf("%v\r", highlight_logic)

    ClearBackground(BLACK)
    // draw board_rect and line separators
    defer {
        render_board(game, .BOARD, FONT_SIZE, 6, 3)
        mu_rl.render(ctx)
    }
    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Number in hand:"),
        auto_cast (board.rect.x + board.rect.width + 50),
        auto_cast board.rect.y + 20,
        25,
        RAYWHITE,
    )

    piece_in_hand_ok, ok := piece_in_hand.?
    if ok {
        DrawText(
            fmt.ctprintf("%d", piece_in_hand_ok.number),
            auto_cast (board.rect.x + board.rect.width + 120),
            auto_cast board.rect.y + 59,
            FONT_SIZE,
            RAYWHITE,
        )
    }

    DrawText(
        fmt.ctprintf("Flipped Pieces:"),
        auto_cast flipped_board.rect.x,
        auto_cast flipped_board.rect.y - 75,
        FONT_SIZE - 20,
        RAYWHITE,
    )
    render_board(game, .FLIPPED, 30, 2, 1)
}

init_game :: proc() -> Game {
    game: Game
    for i in 1 ..= 20 {
        game.number_pieces[i - 1].number = i
    }

    {
        using game.board
        rows = 4
        columns = 4
        rect = rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
        square_length = rect.width / auto_cast columns
    }

    {
        using game.flipped_board
        rows = 2
        columns = 10
        rect = game.board.rect
        rect.y -= 200
        rect.x -= 100
        square_length = rect.width / auto_cast columns
        rect.height = 2 * square_length
    }

    when ODIN_DEBUG {
        /* game.number_pieces[0].piece_state = .FLIPPED */
        /* game.number_pieces[1].piece_state = .FLIPPED */
        /* game.number_pieces[2].piece_state = .FLIPPED */
    }
    return game
}

get_numbers_on_board :: proc(game: ^Game, temp_allocator := context.temp_allocator) -> []int {
    using game.board
    board_numbers := make([]int, rows * columns, temp_allocator)

    for piece in game.number_pieces do if piece.piece_state == .ON_BOARD {
            i, j := expand_values(piece.cell_coords)
            board_numbers[i + j * rows] = piece.number
        }

    return board_numbers
}

draw_number_in_square :: proc(board: Board_matrix, number: int, cell_coords: [2]int, font_size: f32) {
    assert(number != 0)
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, font_size, FONT_SPACING)
    box_rect := get_cell_rect(board, cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(board.square_length - measure.x) / 2, (board.square_length - measure.y) / 2 + 2},
        font_size,
        FONT_SPACING,
        RAYWHITE,
    )
}

take_random_piece_in_hand :: proc(
    number_pieces: []Number_piece,
    piece_type_to_take: Piece_state,
) -> Maybe(^Number_piece) {
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

get_cell_rect :: #force_inline proc(using board: Board_matrix, cell_coords: [2]int) -> rl.Rectangle {
    return(
        rl.Rectangle{
            x = rect.x + square_length * auto_cast cell_coords.y,
            y = rect.y + square_length * auto_cast cell_coords.x,
            width = square_length,
            height = square_length,
        } \
    )
}

render_board :: proc(game: ^Game, board_to_render: Board_type, font_size, boarder_thickness, grid_thickness: int) {
    using rl
    board: Board_matrix
    if board_to_render == .BOARD {
        board = game.board
    } else {
        board = game.flipped_board
    }

    using board
    origine := Vector2{rect.x, rect.y}

    if game.highlight_logic.board_type == board_to_render {
        box_rect := get_cell_rect(board, game.highlight_logic.cell_coord)
        DrawRectangleRec(box_rect, GRAY)
    }

    // board_rect
    DrawRectangleLinesEx(rect, auto_cast boarder_thickness, RAYWHITE)
    // vertical
    for i in 0 ..< columns - 1 {
        x: f32 = auto_cast square_length * (auto_cast i + 1)
        start := origine + {x, 0}
        end := origine + {x, rect.height}
        DrawLineEx(start, end, auto_cast grid_thickness, RAYWHITE)
    }
    // horizontal
    for i in 0 ..< rows - 1 {
        y: f32 = auto_cast square_length * (auto_cast i + 1)
        start := origine + {0, y}
        end := origine + {rect.width, y}
        DrawLineEx(start, end, auto_cast grid_thickness, RAYWHITE)
    }
    // numbers
    if board_to_render == .BOARD {
        board_numbers := get_numbers_on_board(game)
        for i in 0 ..< rows {
            for j in 0 ..< columns {
                number := board_numbers[i + j * rows]
                if number != 0 do draw_number_in_square(board, number, {i, j}, auto_cast font_size)
            }
        }
    } else {
        for piece in game.number_pieces do if piece.piece_state == .FLIPPED {
                using piece
                i, j := (number - 1) / 10, (number - 1) % 10
                draw_number_in_square(board, number, {i, j}, auto_cast font_size)
            }
    }
}

/* get_board_cell :: #force_inline proc(board: Board_matrix, cell_coords: [2]int) -> ^Cell_state { */
/*     using board */
/*     assert(cell_coords[0] >= 0 && cell_coords[0] < rows) */
/*     assert(cell_coords[1] >= 0 && cell_coords[1] < columns) */
/*     return &cells[cell_coords[0] + cell_coords[1] * rows] */
/* } */

import "core:fmt"
import "core:c"
import "core:math/rand"
import "core:mem"
import mu "vendor:microui"
import mu_rl "micro_ui_raylib"
import rl "vendor:raylib"

main :: proc() {
    using rl, mu_rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Irish Integers")
    defer CloseWindow()

    // TODO: Make an init function fo microui ctx 
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
            for number_piece in &game.number_pieces do number_piece.piece_state = .HIDDEN
            state = .NEW_PIECE
        }
        game_logic(&game, ctx)
        render_game(&game, ctx)
        free_all(context.temp_allocator)
    }
}
