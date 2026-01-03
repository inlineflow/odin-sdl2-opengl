package main

import "core:fmt"
import sdl "sdl2"
import glm "core:math/linalg/glsl"
import gl "opengl"

main :: proc() {
  WINDOW_WIDTH :: 800
  WINDOW_HEIGHT :: 600
  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL, .RESIZABLE})
  if window == nil {
    fmt.eprintln("Failed to create window")
    return
  }
  defer sdl.DestroyWindow(window)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
  program, program_ok := gl.load_shaders_source(vertex_source, fragment_source)
  if !program_ok {
    fmt.eprintln("Failed to create GLSL program")
    return
  }
  defer gl.DeleteProgram(program)
  gl.UseProgram(program)

  // vertices := [?]f32 {
  //   -0.5, -0.5, 0,
  //   0.5, -0.5, 0,
  //   0.0, 0.5, 0,
  // }

  // triangle_mat := glm.mat3{
  //   -0.5, -0.5, 0,
  //   0.5, -0.5, 0,
  //   0.0, 0.5, 0,
  // }

  vertices := #row_major matrix[3,3]f32{
    -0.5, -0.5, 0,
    0.5, -0.5, 0,
    0.0, 0.5, 0,
   }

  vbo: u32
  vao: u32

  gl.GenVertexArrays(1, &vao); defer gl.DeleteVertexArrays(1, &vao)
  gl.GenBuffers(1, &vbo); defer gl.DeleteBuffers(1, &vbo)
  gl.BindVertexArray(vao)
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)

  // fmt.printfln("size_of mat3: %v", size_of(triangle_mat))
  fmt.printfln("size_of 3 * f32: %v", 3 * size_of(f32))
  fmt.printfln("size_of [?]f32: %v", size_of(vertices))

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
        case .WINDOWEVENT:
          width: i32
          height: i32

          sdl.GL_GetDrawableSize(window, &width, &height)
          gl.Viewport(0, 0, width, height)
      }
    }
    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    gl.DrawArrays(gl.TRIANGLES, 0, 3)
    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}

vertex_source := `#version 330 core

layout(location = 0) in vec3 aPos;

void main() {
  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
`

fragment_source := `#version 330 core
out vec4 FragColor;

void main() {
  FragColor = vec4(1.0, 0.5, 0.2, 1.0);
}
`
