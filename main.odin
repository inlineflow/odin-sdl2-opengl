package main

import "core:fmt"
import sdl "sdl2"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import gl "opengl"
import "core:time"
import stbi "stb/image"
import "core:math"

Vector4 :: [4]f32
Vector3 :: [3]f32

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
  stbi.set_flip_vertically_on_load(1)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
  program_color, program_color_ok := gl.load_shaders_source(vertex_source, fragment_source_color)
  if !program_color_ok {
    fmt.eprintln("Failed to create orange GLSL program")
    return
  }
  defer gl.DeleteProgram(program_color)

  vbo: u32
  vao: u32
  ebo: u32

  vertices := [?]f32 {
    // postions        // colors        // texture coords
    0.5, 0.5, 0,        1, 0, 0,        1, 1,
    0.5, -0.5, 0,       0, 1, 0,        1, 0,
    -0.5, -0.5, 0,      0, 0, 1,        0, 0,
    -0.5, 0.5, 0,       1, 1, 1,        0, 1,
  }

  indices := [?]u32 {
    0, 1, 3,
    1, 2, 3,
  }


  gl.GenVertexArrays(1, &vao)
  gl.GenBuffers(1, &vbo)
  gl.GenBuffers(1, &ebo)
  gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)
  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
  gl.EnableVertexAttribArray(1)
  gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
  gl.EnableVertexAttribArray(2)

  texture: u32
  gl.GenTextures(1, &texture)
  gl.BindTexture(gl.TEXTURE_2D, texture)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

  width1, height1, nrChannels1: i32
  image_data1 := stbi.load("container.jpg", &width1, &height1, &nrChannels1, 3); defer stbi.image_free(image_data1)
  assert(image_data1 != nil, "couldn't load texture container.jpg")

  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width1, height1, 0, gl.RGB, gl.UNSIGNED_BYTE, image_data1)
  gl.GenerateMipmap(gl.TEXTURE_2D)


  texture2: u32
  gl.GenTextures(1, &texture2)
  gl.BindTexture(gl.TEXTURE_2D, texture2)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

  width2, height2, nrChannels2: i32
  image_data2 := stbi.load("awesomeface.png", &width2, &height2, &nrChannels2, 4); defer stbi.image_free(image_data2)
  assert(image_data2 != nil, "couldn't load texture container.jpg")

  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width2, height2, 0, gl.RGBA, gl.UNSIGNED_BYTE, image_data2)
  gl.GenerateMipmap(gl.TEXTURE_2D)


  start_tick := time.tick_now()
  blend:f32 = 0.2
  gl.UseProgram(program_color)
  gl.Uniform1i(gl.GetUniformLocation(program_color, "texture1"), 0)
  gl.Uniform1i(gl.GetUniformLocation(program_color, "texture2"), 1)
  vec := Vector4 {1, 0, 0, 1}
  // identity := glm.identity(matrix[4,4]f32)

  loop: for {
    event: sdl.Event
    for sdl.PollEvent(&event) {
      #partial switch event.type {
      case .KEYDOWN: 
        #partial switch event.key.keysym.sym {
        case .ESCAPE:
          break loop
        case .DOWN:
          new_val:f32 = blend - 0.1
          blend = math.max(0, new_val)
          fmt.println(blend)
        case .UP:
          new_val:f32 = blend + 0.1
          blend = math.min(1, new_val)
          fmt.println(blend)
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
    t:f32 = cast(f32)(cast(f32)counter  /  cast(f32)freq)
    fmt.println(t)
    gl.Uniform1f(gl.GetUniformLocation(program_color, "blend"), blend)
    translate := glm.mat4Translate(Vector3{0.5, -0.5, 0})
    rotate := glm.mat4Rotate(Vector3{0,0,1}, t)
    // transform := rotate * translate
    transform := translate * rotate

    // fmt.println(transform)


    // rot := glm.mat4Rotate(Vector3{0,0,1}, glm.radians(cast(f32)90))
    // scale := glm.mat4Scale(Vector3{0.5, 0.5, 0.5})
    // transform := rot * scale

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.ActiveTexture(gl.TEXTURE1)
    gl.BindTexture(gl.TEXTURE_2D, texture2)
    gl.UseProgram(program_color)
    // draw_triangle1(program_color)
    gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
    gl.UniformMatrix4fv(gl.GetUniformLocation(program_color, "transform"),
    1, gl.FALSE, &transform[0][0])

    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}

vertex_source := `#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

uniform mat4 transform;

out vec3 vertex_color;
out vec2 TexCoord;

void main() {
  gl_Position = transform * vec4(aPos, 1.0);
  vertex_color = aColor;
  TexCoord = aTexCoord;
}
`

fragment_source_color := `#version 330 core
out vec4 frag_color;
in vec3 vertex_color;
in vec2 TexCoord;

uniform sampler2D texture1;
uniform sampler2D texture2;
uniform float blend;

void main() {
  frag_color = mix(texture(texture1, TexCoord),
                   texture(texture2, TexCoord), blend);
}
`
