package main

import "core:fmt"
import sdl "sdl2"
import glm "core:math/linalg/glsl"
import gl "opengl"
import "core:time"

vaos := [?]u32 {
  0, 0
}

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
  program_orange, program_ok := gl.load_shaders_source(vertex_source, fragment_source_orange)
  if !program_ok {
    fmt.eprintln("Failed to create orange GLSL program")
    return
  }
  defer gl.DeleteProgram(program_orange)

  program_yellow, program_yellow_ok := gl.load_shaders_source(vertex_source, fragment_source_yellow)
  if !program_yellow_ok {
    fmt.eprintln("Failed to create yellow GLSL program")
    return
  }
  defer gl.DeleteProgram(program_yellow)

  program_color, program_color_ok := gl.load_shaders_source(vertex_source, fragment_source_color)
  if !program_color_ok {
    fmt.eprintln("Failed to create orange GLSL program")
    return
  }
  defer gl.DeleteProgram(program_orange)

  setup_triangle1 :: proc() {
    vbo: u32
    vao: u32

    vertices := [?]f32 {
      // postions        // colors
      -0.5, 0, 0,        1, 0, 0,
      -0.25, 0.5, 0,     0, 1, 0,
      0, 0, 0,           0, 0, 1,

    }

    gl.GenVertexArrays(1, &vao)
    // defer gl.DeleteVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    // defer gl.DeleteBuffers(1, &vbo)
    gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
    vaos[0] = vao
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)
  }

  setup_triangle2 :: proc() {
    vao: u32
    vbo: u32

    vertices := [?]f32 {
      // tri2
      0.75, 0, 0,
      0.5, 0.5, 0,
      0.25, 0, 0,
    }

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    vaos[1] = vao
    gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

  }

  draw_triangle1 :: proc(program_id: u32) {
    gl.UseProgram(program_id)
    vao := vaos[0]
    gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
    gl.DrawArrays(gl.TRIANGLES, 0, 3)
  }

  draw_triangle2 :: proc(program_id: u32) {
    gl.UseProgram(program_id)
    vao := vaos[1]
    gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
    gl.DrawArrays(gl.TRIANGLES, 0, 3)
  }


  setup_triangle1()
  // setup_triangle2()
  uniforms := gl.get_uniforms_from_program(program_color)
  defer gl.destroy_uniforms(uniforms)

  fmt.println(uniforms)

  start_tick := time.tick_now()

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
    counter := sdl.GetPerformanceCounter()
    freq := sdl.GetPerformanceFrequency()
    t:f32 = cast(f32)(counter * 1000 /  freq)
    fmt.println(t)
    green := glm.sin(t) / 2 + 0.5
    gl.UseProgram(program_color)
    // vertex_color_uniform := uniforms["ourColor"]

    draw_triangle1(program_color)
    // draw_triangle2(program_yellow)
    // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
    // gl.BindVertexArray(0)
    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}

vertex_source := `#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 vertex_color;

void main() {
  gl_Position = vec4(aPos, 1.0);
  vertex_color = aColor;
}
`

fragment_source_orange := `#version 330 core
in vec4 vertexColor;
out vec4 FragColor;

void main() {
  FragColor = vertexColor;
  // FragColor = vec4(1.0, 0.5, 0.2, 1.0);
}
`

fragment_source_yellow := `#version 330 core
out vec4 FragColor;

void main() {
  FragColor = vec4(1.0, 1.0, 0.0, 1.0);
}
`

fragment_source_color := `#version 330 core
out vec4 frag_color;
in vec3 vertex_color;

void main() {
  frag_color = vec4(vertex_color, 1.0);
}
`
