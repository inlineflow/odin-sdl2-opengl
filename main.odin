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
import "core:strconv"
import vmem "core:mem/virtual"
import "core:container/small_array"

vec4 :: [4]f32
vec3 :: [3]f32
vec2 :: [2]f32
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

PLAYER_SIZE :: vec2{100, 20} 
BALL_VELOCITY :: vec2{ 100 , -350 * 2 }
BALL_RADIUS:f32:12.5
PLAYER_INITIAL_POS :=  vec2{cast(f32)(cast(f32)WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2), cast(f32)(cast(f32)WINDOW_HEIGHT - PLAYER_SIZE.y)}
BALL_INITIAL_POS := PLAYER_INITIAL_POS + { PLAYER_SIZE.x / 2 - BALL_RADIUS, -BALL_RADIUS * 2, }

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



load_texture :: proc(filename: string, desiredChannels: i32, image_format: u32) -> (tex: Texture2D, ok: bool) {
  nrChannels: i32
  fname := strings.clone_to_cstring(filename, context.temp_allocator)
  image_data := stbi.load(fname, &tex.width, &tex.height, &nrChannels, desiredChannels)
  if image_data == nil {
    return
  }

  tex.internal_texture_format = cast(i32)image_format
  tex.image_format = image_format
  tex.wrap_s = gl.REPEAT
  tex.wrap_t = gl.REPEAT
  tex.filter_min = gl.LINEAR
  tex.filter_max = gl.LINEAR

  gl.GenTextures(1, &tex.id)
  gl.BindTexture(gl.TEXTURE_2D, tex.id); defer gl.BindTexture(gl.TEXTURE_2D, 0)
  gl.TexImage2D(gl.TEXTURE_2D, 0, tex.internal_texture_format, tex.width, tex.height, 0, tex.image_format, gl.UNSIGNED_BYTE, image_data)
  fmt.println("len sprites: ", len(Sprites))
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, tex.wrap_s)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, tex.wrap_t)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, tex.filter_min)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, tex.filter_max)

  return tex, true
}

bind_texture :: proc(tex: ^Texture2D) {
  gl.BindTexture(gl.TEXTURE_2D, tex.id)
}

GameState :: enum {
  Active,
  Menu,
  Win,
}

Key :: struct {
  code: sdl.Keycode,
  was_down: bool,
  is_down: bool,
}

Game :: struct {
  state: GameState,
  width: i32,
  height: i32,
  keys: map[i32]Key, // this is sdl.Scancode
  levels: [dynamic]Game_Level,
  player: ^Player,
  ball: ^Ball,
  active_level: i32,
}

Ball :: struct {
  using entity: Entity,
  radius: f32,
  stuck: bool,
  velocity: vec2,
}

Game_Level :: struct {
  rows: i32,
  cols: i32,
  width: i32,
  height: i32,
  bricks: []Brick,
  is_complete: bool,
  arena: vmem.Arena,
}

Entity :: struct {
  pos: vec2,
  size: vec2,
  sprite: ^Sprite2D,
  rotation_degrees: f32,
}

Brick :: struct {
  using entity: Entity,
  is_solid: bool,
  destroyed: bool,
  color: vec3,
}

Player :: struct {
  using entity: Entity,
  velocity: f32,
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

Sprite2D :: struct {
  vao: u32,
  shader: Shader,
  texture: ^Texture2D,
}

Direction :: enum {
  UP,
  RIGHT,
  DOWN,
  LEFT
}

Collision :: struct {
  occured: bool,
  direction: Direction,
  distance: vec2,
}

init_sprite_render_data :: proc(s: Shader, tex: ^Texture2D) -> (rd: Sprite2D) {
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
  rd.texture = tex

  return rd
}

draw_sprite :: proc(pos, size: vec2, rotation_angle: f32, rd: Sprite2D, color: vec3, projection: ^matrix[4,4]f32) {
  gl.UseProgram(rd.shader.id)
  color := color
  translate := glm.mat4Translate(vec3{pos.x, pos.y, 1.0})
  scale_offset_plus := glm.mat4Translate(vec3{0.5 * size.x, 0.5 * size.y, 0})
  rotate := glm.mat4Rotate(vec3{0, 0, 1}, glm.radians(rotation_angle))
  scale_offset_minus := glm.mat4Translate(vec3{-0.5 * size.x, -0.5 * size.y, 0})
  scale := glm.mat4Scale(vec3{size.x, size.y, 1.0})
  // transform := scale * scale_offset_plus * rotate * scale_offset_minus * translate
  // transform := scale * scale_offset * rotate * translate
  transform := translate * scale_offset_plus * rotate * scale_offset_minus * scale

  gl.UniformMatrix4fv(rd.shader.uniforms["model"].location, 1, false, &transform[0][0])
  gl.UniformMatrix4fv(rd.shader.uniforms["projection"].location, 1, false, &projection^[0][0])
  gl.Uniform3fv(rd.shader.uniforms["sprite_color"].location, 1, &color[0])

  gl.ActiveTexture(gl.TEXTURE0)
  bind_texture(rd.texture)

  gl.BindVertexArray(rd.vao); defer gl.BindVertexArray(0)
  gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

vector_direction :: proc(target: vec2) -> Direction {
  compass := [?]vec2 {
    {0, 1},
    {1, 0},
    {0, -1},
    {-1, 0},
  }

  max:f32 = 0
  best_match := -1
  for direct, index in compass {
    dot_product: f32 = glm.dot(glm.normalize(target), direct)
    if dot_product > max {
      max = dot_product
      best_match = index
    }
  }

  return cast(Direction)best_match
}

update_game :: proc(game: ^Game, dt: f32) {
  if game.state == GameState.Active {    // velocity := 0
    // ball movement
    ball := game.ball
    player := game.player
    if !ball.stuck {
      ball.pos += ball.velocity * dt
      if ball.pos.x <= 1 {
        ball.velocity.x = -ball.velocity.x
        ball.pos.x = 0  
      } else if ball.pos.x + ball.size.x >= cast(f32)game.width {
        ball.velocity.x = -ball.velocity.x
        ball.pos.x = cast(f32)game.width - ball.size.x
      }
      if ball.pos.y <= 0 {
        ball.velocity.y = -ball.velocity.y
        ball.pos.y = 0
      }
    }
    check_collision :: proc(ball: ^Ball, entity: Entity) -> Collision {
      center := ball.pos + ball.radius 
      aabb_half_extents := entity.size / 2
      aabb_center := entity.pos + aabb_half_extents

      difference := center - aabb_center
      clamped := glm.clamp(difference, -aabb_half_extents, aabb_half_extents)
      closest := aabb_center + clamped
      difference = closest - center
      if glm.length(difference) < ball.radius {
        return Collision{ true, vector_direction(difference), difference }
      } else {
        return Collision{ false, .UP, vec2{0,0} }
      }
    }

    // checking collisions
    for &brick in game.levels[game.active_level].bricks {
      if !brick.destroyed {
        collision := check_collision(ball, brick)
        if collision.occured {
          if !brick.is_solid do brick.destroyed = true 
          dir := collision.direction
          diff := collision.distance
          if dir == .LEFT || dir == .RIGHT {
            ball.velocity.x = -ball.velocity.x
            penetration:f32 = ball.radius - glm.abs(diff.x)
            if dir == .LEFT {
              ball.pos.x += penetration
            } else {
              ball.pos.x -= penetration
            }
          } else {
            ball.velocity.y = -ball.velocity.y
            penetration:f32 = ball.radius - glm.abs(diff.y)
            if dir == .UP {
              ball.pos.y += penetration
            } else {
              ball.pos.y -= penetration
            }
          }
        }
      }
    }

    collision := check_collision(ball, player)
    if !ball.stuck && collision.occured {
      center_board := player.pos.x + player.size.x / 2
      distance := ball.pos.x + ball.radius - center_board
      percentage := distance / (player.size.x / 2)
      strength:f32 = 2
      old_velocity := ball.velocity
      ball.velocity.x = BALL_VELOCITY.x * percentage * strength
      ball.velocity.y = -1 * glm.abs(ball.velocity.y)
      ball.velocity = glm.normalize(ball.velocity) * glm.length(old_velocity)
    }

    if ball.pos.y >= cast(f32)game.height {
      reset_level(game)
      reset_player(game.player)
    }

    player_velocity := game.player.velocity * dt
    for k in game.keys {
      #partial switch cast(sdl.Scancode)k {
        case .A: {
          if game.keys[k].is_down {
            if game.player.pos.x >= 0 {
              game.player.pos.x -= player_velocity

              if ball.stuck do ball.pos.x -= player_velocity
            }
          }
        }
        case .D: {
          if game.keys[k].is_down {
            if game.player.pos.x <= cast(f32)game.width - game.player.size.x {
              game.player.pos.x += player_velocity
              if ball.stuck do ball.pos.x += player_velocity
            }
          }
        }
        case .SPACE:
          if game.keys[k].is_down do ball.stuck = false
      }
    }
    // for k in small_array.slice(&game.keys) {
    //   #partial switch k {
    //   case .A:
    //     if game.player.pos.x >= 0 {
    //       game.player.pos.x -= velocity
    //     }
    //   case .D:
    //     if game.player.pos.x <= cast(f32)game.width - game.player.size.x {
    //       game.player.pos.x += velocity
    //     }
    //
    //   }
    // }
  }
}

render_game :: proc(game: ^Game, tex: Texture2D, rd: Sprite2D, projection: ^matrix[4,4]f32) {
  background := Sprites["background"]
  draw_sprite(vec2{0, 0}, vec2{cast(f32)game.width, cast(f32)game.height}, 0, background, vec3{1, 1, 1}, projection)


  lvl := game.levels[game.active_level]
  for brick in lvl.bricks {
    if !brick.destroyed {
      draw_sprite(brick.pos, brick.size, brick.rotation_degrees, brick.sprite^, brick.color, projection)
    }
  }

  // player
  p := game.player
  draw_sprite(p.pos, p.size, p.rotation_degrees, p.sprite^, vec3{1,1,1}, projection)

  // ball
  b := game.ball
  draw_sprite(b.pos, vec2{ b.radius * 2, b.radius * 2 }, b.rotation_degrees, b.sprite^, vec3{1,1,1}, projection)
}

Block_Type :: enum {
  EMPTY,
  SOLID,
  BLUE,
  GREEN,
  GOLDEN,
  RED,
}

Sprites := map[string]Sprite2D{}

load_level :: proc(game: ^Game, name: string, width, height: i32) -> (ok: bool) {
  level_arena: vmem.Arena
  arena_allocator := vmem.arena_allocator(&level_arena)
  dir := "levels/"
  level_name := strings.concatenate([]string{dir, name}, context.temp_allocator)
  data := os.read_entire_file(level_name, context.temp_allocator) or_return
  it := string(data)
  cols:= 0
  lines_raw := strings.split_lines(it, context.temp_allocator)
  lines := make([dynamic]string, context.temp_allocator)
  for lr in lines_raw {
    if lr != "" {
      append(&lines, strings.trim_space(lr))
    }
  }

  // NOTE(danil): perhaps using a fixed max size instead of [dynamic, dynamic] would be better
  rows := make([dynamic][dynamic]int, arena_allocator)
  for line in lines {
    chars := strings.split(line, " ", context.temp_allocator)
    cols = math.max(cols, len(chars))
    row := make([dynamic]int, context.temp_allocator)
    for char in chars {
      i, ok := strconv.parse_int(char)
      assert(ok, "failed to parse block in a level")
      append(&row, i)
      // fmt.println(char)
    }

    append(&rows, row)
  }

  bricks := init_level_bricks(width, height, len(rows), cols, rows, arena_allocator)

  PLAYER_VELOCITY :: 700
  PLAYER_SIZE :: vec2{100, 20} 
  player_sprite := &Sprites["paddle"]
  player_pos := vec2{
    cast(f32)(cast(f32)width / 2 - PLAYER_SIZE.x / 2), 
    cast(f32)(cast(f32)height - PLAYER_SIZE.y)}

  // p := new_entity(Player, context.allocator)

  lvl := Game_Level{
    rows = cast(i32)len(rows),
    cols = cast(i32)cols,
    width = width,
    height = height,
    bricks = bricks,
    is_complete = false,
    arena = level_arena,
  }

  append(&game.levels, lvl)
  return true
}

init_level_bricks :: proc(lvl_width, lvl_height: i32, rows, cols: int, tiles: [dynamic][dynamic]int, allocator := context.allocator) -> []Brick {
  // NOTE(danil): I don't like using [dynamic] everywhere
  entities := make([dynamic]Brick, allocator)
  unit_width:f32 = cast(f32)lvl_width / cast(f32)cols
  unit_height:f32 = cast(f32)lvl_height / 2 / cast(f32)rows
  // fmt.println("rows: ", rows)
  // fmt.println("cols: ", cols)
  // fmt.println("tiles: ", tiles)
  // fmt.println("len(tiles): ", len(tiles))
  spr := &Sprites["block"]
  color:vec3
  for y in 0..<rows {
    for x in 0..<len(tiles[y]) {
      is_solid := false
      spr := &Sprites["block"]
      color:vec3
      switch cast(Block_Type)tiles[y][x] {
      case .EMPTY:
        continue
      case .SOLID:
        color = vec3{1,1,1}
        is_solid = true
        spr = &Sprites["block_solid"]
      case .BLUE:
        color = vec3{0.2, 0.6, 1}
      case .GREEN:
        color = vec3{0, 0.7, 0}
      case .GOLDEN:
        color = vec3{0.8, 0.8, 0.4}
      case .RED:
        color = vec3{1, 0.5, 0}
      case:
        assert(false, "unreachable")
      }

      pos := vec2{ unit_width * cast(f32)x, unit_height * cast(f32)y }
      size := vec2{ unit_width, unit_height }
      brick := Brick{
        pos = pos,
        size = size,
        sprite = spr,
        is_solid = is_solid,
        color = color,
      }
      append(&entities, brick)
    }
  }

  return entities[:]
}

reset_level :: proc(game: ^Game) {
  for &brick in game.levels[game.active_level].bricks {
    brick.destroyed = false
    game.ball.pos = BALL_INITIAL_POS
  }
    game.ball.stuck = true
}

reset_player :: proc(player: ^Player) {
  player.pos = PLAYER_INITIAL_POS
}

main :: proc() {
  sdl.Init({.TIMER, .VIDEO})

  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL, .RESIZABLE})
  if window == nil {
    fmt.eprintln("Failed to create window")
    return
  }
  defer sdl.DestroyWindow(window)
  fmt.println(window)
  stbi.set_flip_vertically_on_load(0)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
  gl.Enable(gl.BLEND)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

  s, ok := load_shader("shaders/default.vert", "shaders/default.frag")
  if !ok {
    fmt.eprintln("couldn't load shader")
    return
  }

  block, block_ok := load_texture("block.png", 4, gl.RGBA)
  if !block_ok {
    fmt.eprintln("Couldn't load texture block.png")
    return
  }
  sprite_render_data := init_sprite_render_data(s, &block)
  Sprites["block"] = sprite_render_data
  // fmt.println(Sprites["block"])
  start_tick := time.tick_now()
  blend:f32 = 0.2
  projection := glm.mat4Ortho3d(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1)

  block_solid, block_solid_ok := load_texture("block_solid.png", 4, gl.RGBA)
  if !block_solid_ok {
    fmt.eprintln("Couldn't load texture block_solid.png")
    return
  }

  block_solid_sprite := init_sprite_render_data(s, &block_solid)
  Sprites["block_solid"] = block_solid_sprite

  background, background_ok := load_texture("background.jpg", 3, gl.RGB)
  if !background_ok {
    fmt.eprintln("Couldn't load texture block_solid.png")
    return
  }
  background_sprite := init_sprite_render_data(s, &background)
  Sprites["background"] = background_sprite

  paddle, paddle_ok := load_texture("paddle.png", 4, gl.RGBA)
  if !paddle_ok {
    fmt.eprintln("Couldn't load texture paddle.png")
    return
  }
  paddle_sprite := init_sprite_render_data(s, &paddle)
  Sprites["paddle"] = paddle_sprite

  PLAYER_VELOCITY :: 500
  player_sprite := &Sprites["paddle"]
  player_pos := vec2{
    cast(f32)(cast(f32)WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2), 
    cast(f32)(cast(f32)WINDOW_HEIGHT - PLAYER_SIZE.y)}

  player := Player{
    pos = player_pos,
    sprite = player_sprite,
    size = PLAYER_SIZE,
    velocity = PLAYER_VELOCITY,
  }

  ball_tex, ball_tex_ok := load_texture("awesomeface.png", 4, gl.RGBA)
  if !ball_tex_ok {
    fmt.eprintln("Couldn't load texture awesomeface.png")
    return
  }

  ball_sprite := init_sprite_render_data(s, &ball_tex)
  Sprites["ball"] = ball_sprite

  ball := Ball{
    pos = player_pos + {
      PLAYER_SIZE.x / 2 - BALL_RADIUS,
      -BALL_RADIUS * 2,
    },
    sprite = &ball_sprite,
    radius = BALL_RADIUS,
    stuck = true,
    velocity = BALL_VELOCITY,
  }
  game := Game{
    state = GameState.Active,
    width = WINDOW_WIDTH,
    height = WINDOW_HEIGHT,
    levels = {},
    keys = make(map[i32]Key),
    player = &player,
    ball = &ball,
  }

  level_ok := load_level(&game, "1.lvl", WINDOW_WIDTH, WINDOW_HEIGHT)
  if !level_ok {
    fmt.eprintln("COULDN'T LOAD LEVEL AAAAAAAAAAAAAAAAAAAAA")
    return
  }


  free_all(context.temp_allocator)
  now:u64 = 0
  last: u64 = sdl.GetPerformanceCounter()
  dt: f32 = 0
  freq := sdl.GetPerformanceFrequency()

  loop: for {
    
    now = sdl.GetPerformanceCounter()
    elapsed_ticks: u64 = now - last
    dt = cast(f32)(cast(f64)elapsed_ticks / cast(f64)freq) // in seconds
    last = now

    event: sdl.Event
    for sdl.PollEvent(&event) {
      #partial switch event.type {
      case .KEYDOWN: 
        fallthrough
      case .KEYUP:
        // key := event.key.keysym.sym
        // key.code = event.key.keysym.sym
        was_down := false
        is_down := event.key.state == sdl.PRESSED
        if event.key.state == sdl.RELEASED {
          was_down = true
        } else if event.key.repeat != 0 {
          was_down = true
        }

        #partial switch event.key.keysym.sym {
        case .ESCAPE:
          break loop
        }
        #partial switch event.key.keysym.scancode {
        case .A:
          fallthrough
        case .D:
          fallthrough
        case .SPACE:
          new_key := Key{
            is_down = is_down,
            was_down = was_down,
            code = event.key.keysym.sym,
          }
          game.keys[cast(i32)event.key.keysym.scancode] = new_key
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
    // fmt.println(dt * 1000)
    // fmt.println(dt)
    update_game(&game, dt)
    render_game(&game, block, sprite_render_data, &projection)
    // fmt.println(game.keys)
    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}
