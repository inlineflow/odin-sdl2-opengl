package main

import "core:fmt"
import sdl "sdl2"
import gl "opengl"

main :: proc() {
  WINDOW_WIDTH :: 854
  WINDOW_HEIGHT :: 480
  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL})
  if window == nil {
    fmt.eprintln("Failed to create window")
    return
  }
  defer sdl.DestroyWindow(window)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  loop: for {
    event: sdl.Event
    for sdl.PollEvent(&event) {
      #partial switch event.type {
      case .KEYDOWN: 
        #partial switch event.key.keysym.sym {
        case .ESCAPE:
          break loop
        }
        case .QUIT: 
          break loop
      }
    }
    gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}
