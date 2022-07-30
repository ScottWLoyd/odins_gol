package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import "vendor:sdl2"

SQUARE_SIZE :: 10
UPDATE_INTERVAL :: 50 // milliseconds

GameState :: struct {
    paused: bool,
    mouse_down: bool,
    first_frame_mouse_down: bool,
    painting_val: bool,
    clear_requested: bool,
    last_update: time.Time,
    renderer: ^sdl2.Renderer,
    rows, cols: u32,
    curr_bits: ^[dynamic]bool,
    next_bits: ^[dynamic]bool,
    bits1: [dynamic]bool,
    bits2: [dynamic]bool
}

get_index::proc(state: ^GameState, x: i32, y: i32) -> i32 {
    row := y
    if y < 0 {
        row = cast(i32)state.rows - 1
    } else if y >= cast(i32)state.rows {
        row = 0
    }
    col := x
    if x < 0 {
        col = cast(i32)state.cols - 1
    } else if x >= cast(i32)state.cols {
        col = 0
    }
    return row*cast(i32)state.cols + col
}

get_score::proc(state: ^GameState, x: i32, y:i32) -> int {
    count := 0
    
    if state.curr_bits[get_index(state, x-1, y-1)] { count += 1 }
    if state.curr_bits[get_index(state, x  , y-1)] { count += 1 }
    if state.curr_bits[get_index(state, x+1, y-1)] { count += 1 }
    if state.curr_bits[get_index(state, x-1, y  )] { count += 1 }
    if state.curr_bits[get_index(state, x+1, y  )] { count += 1 }
    if state.curr_bits[get_index(state, x-1, y+1)] { count += 1 }
    if state.curr_bits[get_index(state, x  , y+1)] { count += 1 }
    if state.curr_bits[get_index(state, x+1, y+1)] { count += 1 }

    return count
}

handle_input::proc(state: ^GameState) {
    // update mouse
    if state.mouse_down {
        m_x, m_y: i32;
        sdl2.GetMouseState(&m_x, &m_y)
        grid_x := m_x / SQUARE_SIZE
        grid_y := m_y / SQUARE_SIZE
        index := get_index(state, grid_x, grid_y)
        if (state.first_frame_mouse_down) {
            state.painting_val = !state.curr_bits[index]
            state.first_frame_mouse_down = false
        }
        state.curr_bits[index] = state.painting_val
    }

    if state.clear_requested {
        for i in 0..<len(state.curr_bits) {
            state.curr_bits[i] = false
        }
        state.clear_requested = false
    }
}

update::proc(state: ^GameState) {
    // early return if paused
    if state.paused {
        return
    }

    if time.since(state.last_update) < UPDATE_INTERVAL * time.Millisecond {
        return
    }
    state.last_update = time.now()

    for y in 0..<state.rows {
        for x in 0..<state.cols {
            score := get_score(state, cast(i32)x, cast(i32)y)
            if state.curr_bits[y*state.cols + x] {
                switch(score) {
                    case 0..=1: 
                        state.next_bits[y*state.cols + x] = false
                    case 2..=3:
                        state.next_bits[y*state.cols + x] = true
                    case:
                        state.next_bits[y*state.cols + x] = false
                }
            } else if score == 3 {
                state.next_bits[y*state.cols + x] = true
            } else {
                state.next_bits[y*state.cols + x] = false
            }
        }
    }

    temp := state.next_bits
    state.next_bits = state.curr_bits
    state.curr_bits = temp
}

render::proc(win: ^sdl2.Window, state: ^GameState) {
    using sdl2

    for y in 0..<state.rows {
        for x in 0..<state.cols {
            color := Color{255, 255, 255, 255}
            if state.curr_bits[y*state.cols + x] {
                color = Color{0, 0, 0, 255}
            }

            r := Rect {
                x = auto_cast x*SQUARE_SIZE,
                y = auto_cast y*SQUARE_SIZE,
                w = SQUARE_SIZE,
                h = SQUARE_SIZE
            }

            SetRenderDrawColor(state.renderer, color.r, color.g, color.b, color.a)
            RenderFillRect(state.renderer, &r)
        }
    }
}

main::proc() {
    using sdl2

    if Init(InitFlags{.VIDEO, .EVENTS}) != 0 {
        fmt.println("failed to init SDL: ", GetError())
        return
    }

    win_width : i32 = 1020
    win_height : i32 = 770

    win := CreateWindow("Odin's Game of Life", 
        WINDOWPOS_UNDEFINED, WINDOWPOS_UNDEFINED,
        win_width, win_height, WindowFlags{})
    if win == nil {
        fmt.println("failed to create window: ", GetError())
        return
    }

    renderer := CreateRenderer(win, -1, RENDERER_ACCELERATED)

    // initialize the game
    game_state: GameState
    game_state.renderer = renderer
    game_state.last_update = time.now()
    game_state.rows = auto_cast win_height / SQUARE_SIZE
    game_state.cols = auto_cast win_width / SQUARE_SIZE
    game_state.curr_bits = &game_state.bits1
    game_state.next_bits = &game_state.bits2
    for y in 0..<game_state.rows {
        for x in 0..<game_state.cols {
            append(&game_state.bits1, rand.uint32() % 10 == 1)
            //append(&game_state.bits1, false)
            append(&game_state.bits2, false)
        }
    }    

    running := true
    for running {
        event: Event
        for PollEvent(&event) {
            #partial switch event.type {
                case .QUIT: 
                    running = false
                case .KEYDOWN:
                    #partial switch event.key.keysym.sym {
                        case Keycode.ESCAPE:
                            running = false
                        case Keycode.SPACE:
                            game_state.paused = !game_state.paused
                        case Keycode.C:
                            game_state.clear_requested = true
                    }
                case .MOUSEBUTTONDOWN:
                    game_state.mouse_down = true
                    game_state.first_frame_mouse_down = true
                case .MOUSEBUTTONUP:
                    game_state.mouse_down = false            
            }
        }

        SetRenderDrawColor(game_state.renderer, 0, 0, 0, 1)
        RenderClear(game_state.renderer)

        handle_input(&game_state)
        update(&game_state)
        render(win, &game_state)

        RenderPresent(game_state.renderer)
    }
}