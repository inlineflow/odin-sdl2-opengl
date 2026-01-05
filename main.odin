package main

import "core:fmt"
import sdl "sdl2"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import gl "opengl"
import "core:time"
import stbi "stb/image"
import "core:math"
import "core:os"
import "core:strings"

Vector4 :: [4]f32
Vector3 :: [3]f32

Shader :: struct {
  uniforms: map[string]gl.Uniform_Info,
  id: u32,
}

GameState :: enum {
  Active,
  Menu,
  Win,
}

Game :: struct {
  State: GameState,
  width: u32,
  height: u32,
  keys: []Keycode,
}

load_shader :: proc(vertex_filepath, fragment_filepath: string) -> (s: Shader, ok: bool) {
  vertex_source_data, vert_source_ok := os.read_entire_file_from_filename(vertex_filepath, context.temp_allocator)
  if !vert_source_ok {
    return 
  }

  fragment_source_data, frag_source_ok := os.read_entire_file_from_filename(fragment_filepath, context.temp_allocator)
  if !frag_source_ok {
    return 
  }

  vert_source := strings.clone_to_cstring(string(vertex_source_data), context.temp_allocator)
  frag_source := strings.clone_to_cstring(string(fragment_source_data), context.temp_allocator)

  program, program_ok := gl.load_shaders_source(string(vert_source), string(frag_source))
  if !program_ok {
    fmt.eprintln("Failed to create GLSL program")
    return
  }
  
  uniforms := gl.get_uniforms_from_program(program)

  return Shader {
    uniforms = uniforms,
    id = program,
  }, true
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

  s, ok := load_shader("shaders/default.vert", "shaders/default.frag")

  start_tick := time.tick_now()
  blend:f32 = 0.2
  vec := Vector4 {1, 0, 0, 1}

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
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    counter := sdl.GetPerformanceCounter()
    freq := sdl.GetPerformanceFrequency()
    t:f32 = cast(f32)(cast(f32)counter  /  cast(f32)freq)
    // fmt.println(t)


    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}

vertex_source := `#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vertex_color;
out vec2 TexCoord;

void main() {
  gl_Position = projection * view * model * vec4(aPos, 1.0);
  // gl_Position = transform * vec4(aPos, 1.0);
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
  // frag_color = vec4(1);
  frag_color = mix(texture(texture1, TexCoord),
                   texture(texture2, TexCoord), blend);
}
`
