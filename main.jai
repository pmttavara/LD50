
window_width  : s32 = 640;
window_height : s32 = 480;

#import "Basic";
#import "Math";
v2 :: make_vector2;
Simp :: #import "Simp";
#import "Window_Creation";
Windows :: #import "Windows";
Input :: #import "Input";
#import "Random";

// invfreq :: float64;
// get_time :: () -> float64 {
//     li : LARGE_INTEGER;
//     if !invfreq {
//         QueryPerformanceFrequency(*li);
//         invfreq = 1.0 / li.QuadPart;
//     }
//     QueryPerformanceCounter(*li);
//     return li.QuadPart * invfreq;
// }


normalize :: (v : Vector2) -> Vector2 {
    m := v.x * v.x + v.y * v.y;
    if (m) {
        m = 1.0 / sqrt(m);
    }
    result := v;
    result.x *= m;
    result.y *= m;
    return result;
}

main :: () {
    Windows.timeBeginPeriod(1);
    defer {
        Windows.timeEndPeriod(1);
    }
    user32_dll := Windows.LoadLibraryA("User32.dll");
    if (user32_dll) {
        spdac_type :: #type (s64) -> s32 #c_call;
        spdac := cast(spdac_type) Windows.GetProcAddress(user32_dll, "SetProcessDpiAwarenessContext");
        spda_type :: #type () -> s32 #c_call;
        spda := cast(spda_type) Windows.GetProcAddress(user32_dll, "SetProcessDPIAware");
        set := false;
        if (spdac) {
            if (spdac(-4)) {
                set = true;
            } else if (spdac(-3)) {
                set = true;
            } else if (spdac(-2)) {
                set = true;
            }
        }
        if (!set) {
            shcore_dll := Windows.LoadLibraryA("Shcore.dll");
            if (shcore_dll) {
                spdaness_type :: #type (s32) -> s32;
                spdaness := cast(spdaness_type) Windows.GetProcAddress(shcore_dll, "SetProcessDpiAwareness");
                if (spdaness) {
                    if (!spdaness(2)) {
                        set = true;
                    } else if (!spdaness(1)) {
                        set = true;
                    }
                }
                Windows.FreeLibrary(shcore_dll);
            }
        }
        if (!set) {
            if (spda) {
                if (spda()) {
                    set = true;
                }
            }
        }
        Windows.FreeLibrary(user32_dll);
    }
    window := create_window(window_width, window_height, "Hello");
    Windows.MoveWindow(window, -1900, 100, window_width, window_height, 0); // @Temporary @Remove
    saved_window_info : Saved_Window_Info;
    toggle_fullscreen(window, true, *saved_window_info);
    fullscreen := true;
    Simp.set_render_target(window);

    GL :: #import "GL";
    GL.wglSwapIntervalEXT(0);
    
    stickman: Simp.Texture;
    {
        success := Simp.texture_load_from_file(*stickman, "stickman.png");
        assert(success);
    }
    cursor: Simp.Texture;
    {
        success := Simp.texture_load_from_file(*cursor, "cursor.png");
        assert(success);
    }
    sword: Simp.Texture;
    {
        success := Simp.texture_load_from_file(*sword, "sword.png");
        assert(success);
    }
    rock: Simp.Texture;
    {
        success := Simp.texture_load_from_file(*rock, "rock.png");
        assert(success);
    }
    tree: Simp.Texture;
    {
        success := Simp.texture_load_from_file(*tree, "tree.png");
        assert(success);
    }

    Entity :: struct {
        using pos: Vector2;
        scheduled_for_deletion := false;
    }

    Guy :: struct {
        using entity: Entity;
        vel: Vector2;
    }
    guy: Guy;

    sword_vector := v2(0, 0);

    swing_timer := 0.0;
    SWING_TIME :: 0.25;

    prev := get_time();

    CAMERA_BASE_SCALE :: 35.0;
    Camera :: struct {
        using entity: Entity;
        scale := CAMERA_BASE_SCALE;
    }
    camera: Camera;

    Rock :: struct {
        using entity: Entity;
    }

    Tree :: struct {
        using entity: Entity;
    }

    rocks: [..] Rock;

    trees: [..] Tree;

    reset_game :: () #expand {
        guy = .{};
        sword_vector = .{};
        swing_timer = 0;
        camera = .{};
        rocks.count = 0;
        trees.count = 0;
        random_seed(123456789);
        for y: -50..+50 {
            for x: -50..+50 {
                r := random_get_zero_to_one();
                if (r <= 0.01) {
                    rock : Rock;
                    rock.x = xx x;
                    rock.y = xx y;
                    array_add(*rocks, rock);
                } else if (r <= 0.02) {
                    tree : Tree;
                    tree.x = xx x;
                    tree.y = xx y;
                    array_add(*trees, tree);
                }
            }
        }
    }
    reset_game();

    accumulator := 0.0;

    mouse_pos := v2(0, 0);

    quit := false;
    while !quit {
        {
            speculative_dt := get_time() - prev;
            target_time := cast(float64) 1.0 / 240;
            time_to_sleep := target_time - (accumulator + speculative_dt);
            if time_to_sleep > 0 {
                start := get_time();
                while get_time() - start < time_to_sleep {}
            }
        }
        next := get_time();
        dt := cast(float) (next - prev);
        prev = next;
        accumulator += dt;
        if accumulator > 0.5 {
            accumulator = 0.5;
        }
        
        Input.update_window_events();
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window {
                window_width = it.width;
                window_height = it.height;
            }
        }

        spacebar_pressed := false;
        for Input.events_this_frame {
            if it.type == .QUIT quit = true;

            if it.type == .KEYBOARD {
                if it.key_pressed && !it.repeat {
                    if it.key_code == .F11 || (it.key_code == .ENTER && it.alt_pressed) {
                        fullscreen = !fullscreen;
                        toggle_fullscreen(window, fullscreen, *saved_window_info);
                    }
                    if it.key_code == .F4 && it.alt_pressed {
                        quit = true;
                    }
                    if it.key_code == #char " " || it.key_code == .MOUSE_BUTTON_LEFT {
                        spacebar_pressed = true;
                    }
                    if it.key_code == #char "T" {
                        reset_game();
                    }
                }
            }
        }
        if quit break;
        {
            mouse_x, mouse_y, succ := get_mouse_pointer_position(window, false);
            if succ {
                mouse_pos = v2(cast(float) (mouse_x - window_width / 2) / window_width, cast(float) (window_height / 2 - mouse_y) / window_width) * camera.scale + camera.pos;
            }
        }

        time_scale := 1.0;
        if cast(float) (cast,trunc(u16) Windows.GetKeyState(Windows.VK_SHIFT) >= 0x8000) {
            time_scale *= 0.1;
        }
        while accumulator > 1.0 / 240 {
            accumulator -= 1.0 / 240;

            dt := 1.0 / 240 * time_scale;
            camera.pos -= guy.pos;
            camera.pos *= pow(0.01, dt);
            camera.pos += guy.pos;

            {
                target_scale := CAMERA_BASE_SCALE;
                if length(guy.vel) >= 10 {
                    target_scale *= pow(2.0, (length(guy.vel) - 10) / 50);
                }
                camera.scale -= target_scale;
                camera.scale *= pow(0.1, dt);
                camera.scale += target_scale;
            }

            GUY_SPEED :: 4.0;
            GUY_ACCEL :: GUY_SPEED * 8;
            GUY_TURN_ACCEL :: GUY_ACCEL * 8;
            {
                x := cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "D") >= 0x8000)
                - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "A") >= 0x8000);

                y := cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "W") >= 0x8000)
                - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "S") >= 0x8000);

                camera.scale *= pow(2.0, dt * (cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "R") >= 0x8000)
                                            - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "F") >= 0x8000)));
                
                input := v2(x, y);
                input = normalize(input);

                swing_timer -= dt;
                if spacebar_pressed {
                    if swing_timer < 0 {
                        swing_timer = SWING_TIME;

                        // if dot(guy.vel, sword_vector) < GUY_SPEED * 0.25 {
                        //     guy.vel += sword_vector * 10;
                        // } else {
                        //     guy.vel += sword_vector * 1;
                        // }
                        impulse := 10.0;
                        delta_this_frame := clamp(GUY_SPEED * 2 - dot(guy.vel, sword_vector), 0, impulse);
                        guy.vel += sword_vector * delta_this_frame;
                    }
                }

                accel := GUY_ACCEL;
                {
                    if length(guy.vel) > GUY_SPEED / 8 && length(input) > 0 && dot(normalize(guy.vel), normalize(input)) <= cos(TAU / 16) + 0.01 {
                        accel = GUY_TURN_ACCEL;
                        // print("GUY_TURN_ACCEL!!!!!!!\n");
                    }
                    delta_total := accel * dt;
                    delta_this_frame := clamp(GUY_SPEED - dot(guy.vel, input), 0, delta_total);
                    accel = delta_this_frame / dt;
                }
                    
                guy.vel += dt * accel * input;

                // print("% %% of max speed\n", length(guy.vel) / GUY_SPEED * 100);
                
                if length(input) <= 0.01 {
                    guy.vel *= pow(0.0000001, dt);
                } else {
                    input_perp := v2(input.y, -input.x);
                    orthogonal_vel := input_perp * (dot(guy.vel, input_perp) / dot(input_perp, input_perp));
                    guy.vel -= orthogonal_vel;
                    orthogonal_vel *= pow(0.0000001, dt);
                    guy.vel += orthogonal_vel;

                    // speed := max(GUY_SPEED * 0, length(guy.vel));
                    // friction_amt := speed * 4 * dt;
                    // scale := clamp(speed - friction_amt, 0, speed) / speed;
                    // guy.vel *= scale;
                }
                guy.pos += guy.vel * dt;

                // if swing_timer < 0
                {
                    sword_vector = normalize(mouse_pos - guy.pos);
                }
            }

            for * rocks {
                disp := it.pos - guy.pos;
                dist := length(disp);
                dir := disp / dist;
                if dist == 0 {
                    dir = .{1, 0};
                }
                if dist < 1 {
                    overlap := 1 - dist;
                    it.pos += dir * overlap / 2;
                    guy.pos -= dir * overlap / 2;
                    projection_onto_dir := dot(guy.vel, dir) * dir;
                    if dot(guy.vel, dir) >= 0 {
                        // guy.vel -= projection_onto_dir;
                    }
                    // guy.vel = .{};
                }
            }
            for * a: rocks {
                for * b: rocks {
                    if b == a continue;
                    disp := b.pos - a.pos;
                    dist := length(disp);
                    dir := disp / dist;
                    if dist == 0 {
                        dir = .{1, 0};
                    }
                    if dist < 1 {
                        overlap := 1 - dist;
                        b.pos += dir * overlap / 2;
                    }
                }
            }
            for * rocks {
                v := get_sword_vector(sword_vector, swing_timer, SWING_TIME);

                disp := it.pos - guy.pos;
                dist := length(disp);
                dir := normalize(disp);
                theta :: TAU / 64;
                if dist < 3 && dot(dir, v) >= cos(theta) {
                    if swing_timer > SWING_TIME * 0.75 {
                        guy.vel += v * 5;
                        swing_timer = SWING_TIME * 0.75;
                    }
                }
            }
            for * trees {
                v := get_sword_vector(sword_vector, swing_timer, SWING_TIME);

                disp := it.pos - guy.pos;
                dist := length(disp);
                dir := normalize(disp);
                theta :: TAU / 64;
                if dist < 3 && dot(dir, v) >= cos(theta) {
                    if swing_timer >= SWING_TIME * 0.75 {
                        it.scheduled_for_deletion = true;
                        guy.vel += v * 5;
                    }
                }
            }
            for * trees {
                disp := it.pos - guy.pos;
                dist := length(disp);
                dir := disp / dist;
                if dist == 0 {
                    dir = .{1, 0};
                }
                if dist < 0.75 {
                    overlap := 0.75 - dist;
                    // it.pos += dir * overlap / 2;
                    guy.pos -= dir * overlap;
                    projection_onto_dir := dot(guy.vel, dir) * dir;
                    if dot(guy.vel, dir) >= 0 {
                        guy.vel -= projection_onto_dir;
                    }
                    // guy.vel = .{};
                }
            }

            {
                i := 0;
                while i < trees.count {
                    if trees[i].scheduled_for_deletion {
                        array_ordered_remove_by_index(*trees, i);
                    } else {
                        i += 1;
                    }
                }
            }
        }

        // debug_break();
        Simp.clear_render_target(0, 0, 0, 1);
        draw_rect_core :: (pos: Vector2, camera: *Camera, theta: float, w: float, h: float, color: Vector4) {
            GL.glEnable(GL.GL_BLEND);
            GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);
            p := (pos - camera.pos) / camera.scale;
            rw := v2(xx cos(theta) * w / camera.scale / 2, xx sin(theta) * w / camera.scale / 2);
            rh := v2(xx -sin(theta) * h / camera.scale / 2, xx cos(theta) * h / camera.scale / 2);
            p0 := (p - rw - rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p1 := (p + rw - rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p2 := (p + rw + rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p3 := (p - rw + rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            Simp.immediate_quad(p0, p1, p2, p3, color, color, color, color);
        }
        draw_rect :: (image: * Simp.Texture, pos: Vector2, camera: *Camera, theta: float, w: float, h: float) {
            Simp.set_shader_for_images(image);
            draw_rect_core(pos, camera, theta, w, h, .{1, 1, 1, 1});
        }
        draw_rect :: (pos: Vector2, camera: *Camera, theta: float, w: float, h: float, color: Vector4 = .{1, 1, 1, 1}) {
            Simp.set_shader_for_color();
            draw_rect_core(pos, camera, theta, w, h, color);
        }
        {
            color := Vector4.{0.8, 0.8, 0.8, 0.2};
            if camera.scale > 40 {
                color.w *= 1 - (camera.scale - 40) / 70;
                Clamp(*color.w, 0, 1);
            }
            if color.w {
                for y: cast(int) (camera.y - camera.scale / 2 * window_height / window_width) .. cast(int) (camera.y + camera.scale / 2 * window_height / window_width) {
                    for x: cast(int) (camera.x - camera.scale / 2) .. cast(int) (camera.x + camera.scale / 2) {
                        draw_rect(v2(cast(float) x, cast(float) y), *camera, 0, 0.1, 0.1, color);
                    }
                }
            }
        }

        for * rocks {
            draw_rect(*rock, it.pos, *camera, 0, 1, 1);
        }
        for * trees {
            draw_rect(*tree, it.pos, *camera, 0, 1, 1);
        }

        draw_rect(*stickman, guy.pos, *camera, 0, 1, 1);
        draw_rect(*cursor, mouse_pos, *camera, xx fmod(get_time() / 8, 1) * TAU, 1, 1);
        get_sword_vector :: (base_sword_vector: Vector2, swing_timer: float, $SWING_TIME: float) -> Vector2 {
            x := swing_timer / SWING_TIME;
            K := 0.75;
            if x < K {
                x /= K;
            } else {
                x = 1 - (x - K) / (1 - K);
            }
            x = clamp(x, 0, 1);
            theta := x * TAU / 4 - TAU / 8;
            v := rotate(base_sword_vector, theta);
            return v;
        }
        {
            v := get_sword_vector(sword_vector, swing_timer, SWING_TIME);
            draw_rect(*sword, guy.pos + v * 1.5, *camera, atan2(v.y, v.x), 2, 1);
        }
        Simp.immediate_flush();

        Simp.swap_buffers(window);
    }
}

#run {
    WR :: #import "Windows_Resources";
    // WR.disable_runtime_console();
}