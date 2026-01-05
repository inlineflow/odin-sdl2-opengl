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

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

Shader :: struct {
  uniforms: gl.Uniforms,
  id: u32,
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

Texture2D :: struct {
  id: u32,
  width: i32,
  height: i32,
  internal_texture_format: i32,
  image_format: u32,
  wrap_s: i32,
  wrap_t: i32,
  filter_min: i32,
  filter_max: i32,
}

Render_Data :: struct {
  vao: u32,
  shader: Shader,
  texture: Texture2D,
}


load_texture :: proc(filename: string, nrChannels: u32) -> (tex: Texture2D, ok: bool) {
  nrChannels: i32
  fname := strings.clone_to_cstring(filename, context.temp_allocator)
  image_data := stbi.load(fname, &tex.width, &tex.height, &nrChannels, nrChannels)
  if image_data == nil {
    return
  }

  tex.internal_texture_format = gl.RGB
  tex.image_format = gl.RGB
  tex.wrap_s = gl.REPEAT
  tex.wrap_t = gl.REPEAT
  tex.filter_min = gl.LINEAR
  tex.filter_max = gl.LINEAR

  gl.BindTexture(gl.TEXTURE_2D, tex.id); defer gl.BindTexture(gl.TEXTURE_2D, 0)
  gl.TexImage2D(gl.TEXTURE_2D, 0, tex.internal_texture_format, tex.width, tex.height, 0, tex.image_format, gl.UNSIGNED_BYTE, image_data)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, tex.wrap_s)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, tex.wrap_t)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, tex.filter_min)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, tex.filter_max)

  return tex, true
}

bind_texture :: proc(tex: Texture2D) {
  gl.BindTexture(gl.TEXTURE_2D, tex.id)
}

GameState :: enum {
  Active,
  Menu,
  Win,
}

Game :: struct {
  State: GameState,
  width: i32,
  height: i32,
  keys: []sdl.Keycode,
}

init_sprite_render_data :: proc(s: Shader) -> (rd: Render_Data) {
  vbo: u32
  vertices := [?]f32 {
    // pos    // uv
    0.0, 1.0, 0.0, 1.0,
    1.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 1.0,
    1.0, 1.0, 1.0, 1.0,
    1.0, 0.0, 1.0, 0.0
  }

  gl.GenVertexArrays(1, &rd.vao)
  gl.GenBuffers(1, &vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

  gl.BindVertexArray(rd.vao)
  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
  gl.BindBuffer(gl.ARRAY_BUFFER, 0)
  gl.BindVertexArray(0)
  rd.shader = s
  return rd
}

draw_sprite :: proc(pos, size: Vec2, rotation_angle: f32, tex: Texture2D, rd: Render_Data, color: Vec3) {
  gl.UseProgram(rd.shader.id)
  color := color
  translate := glm.mat4Translate(Vec3{pos.x, pos.y, 1.0})
  scale_offset_plus := glm.mat4Translate(Vec3{0.5 * size.x, 0.5 * size.y, 0})
  rotate := glm.mat4Rotate(Vec3{0, 0, 1}, glm.radians(rotation_angle))
  scale_offset_minus := glm.mat4Translate(Vec3{-0.5 * size.x, -0.5 * size.y, 0})
  scale := glm.mat4Scale(Vec3{size.x, size.y, 1.0})
  transform := scale * scale_offset_plus * rotate * scale_offset_minus * translate
  // transform := scale * scale_offset * rotate * translate

  gl.UniformMatrix4fv(rd.shader.uniforms["model"].location, 1, false, &transform[0][0])
  gl.Uniform3fv(rd.shader.uniforms["sprite_color"].location, 1, &color[0])

  gl.ActiveTexture(gl.TEXTURE0)
  bind_texture(tex)

  gl.BindVertexArray(rd.vao); defer gl.BindVertexArray(0)
  gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

render_game :: proc(game: Game, rd: Render_Data) {
  draw_sprite(Vec2{200, 200}, Vec2{300, 400}, 45.0,  vec3{0, 1, 0)
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
  fmt.println(window)
  stbi.set_flip_vertically_on_load(1)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

  s, ok := load_shader("shaders/default.vert", "shaders/default.frag")
  sprite_render_data := init_sprite_render_data(s)
  fmt.println(sprite_render_data)
  game := Game{}
  start_tick := time.tick_now()
  blend:f32 = 0.2
  projection := glm.mat4Ortho3d(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1)

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
          game.width = width
          game.height = height
          projection = glm.mat4Ortho3d(0, cast(f32)width, cast(f32)height, 0, -1, 1)
          gl.Viewport(0, 0, width, height)
      }
    }


    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    counter := sdl.GetPerformanceCounter()
    freq := sdl.GetPerformanceFrequency()
    t:f32 = cast(f32)(cast(f32)counter  /  cast(f32)freq)
    render_game(game, sprite_render_data)
    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}
