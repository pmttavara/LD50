
window_width  : s32 = 640;
window_height : s32 = 480;

#import "Basic";
#import "Math";
v2 :: make_vector2;
Simp :: #import "Simp";
#import "Window_Creation";
Windows :: #import "Windows";
Input :: #import "Input";

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

    guypos := v2(0, 0);
    guyvel := v2(0, 0);

    sword_vector := v2(0, 0);

    prev := get_time();

    CAMERA_SCALE := 35.0;

    quit := false;
    while !quit {
        next := get_time();
        dt := cast(float) (next - prev);
        prev = next;
        Input.update_window_events();
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window {
                window_width = it.width;
                window_height = it.height;
            }
        }
        for Input.events_this_frame {
            if it.type == .QUIT quit = true;

            if it.type == .KEYBOARD {
                if it.key_pressed && (it.key_code == .F11 || (it.key_code == .ENTER && it.alt_pressed)) {
                    fullscreen = !fullscreen;
                    toggle_fullscreen(window, fullscreen, *saved_window_info);
                }
                if it.key_pressed && (it.key_code == .F4 && it.alt_pressed) {
                    quit = true;
                }
            }
        }
        if quit break;

        mouse_pos := v2(0, 0);
        {
            mouse_x, mouse_y, succ := get_mouse_pointer_position(window, false);
            assert(succ);
            mouse_pos = v2(cast(float) (mouse_x - window_width / 2) / window_width, cast(float) (window_height / 2 - mouse_y) / window_width) * CAMERA_SCALE;
        }

        GUY_SPEED :: 4.0;
        GUY_ACCEL :: 69.0;
        GUY_TURN_ACCEL :: GUY_ACCEL * 8;
        {
            x := cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "D") >= 0x8000)
               - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "A") >= 0x8000);

            y := cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "W") >= 0x8000)
               - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "S") >= 0x8000);

            // CAMERA_SCALE *= pow(2.0, dt * (cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "R") >= 0x8000)
            //                              - cast(float) (cast,trunc(u16) Windows.GetKeyState(#char "F") >= 0x8000)));
            
            input := v2(x, y);
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
            input = normalize(input);

            accel := GUY_ACCEL;
            if dot(normalize(input), normalize(guyvel)) < 0.5 {
                accel = GUY_TURN_ACCEL;
            }
            guyvel += dt * accel * input;
            max_speed := GUY_SPEED;
            if length(input) <= 0.01 {
                max_speed = 0;
            }
            if length(guyvel) > max_speed {
                guyvel /= length(guyvel);
                guyvel *= max_speed;
            }
            guypos += guyvel * dt;

            sword_vector = normalize(mouse_pos - guypos);
        }

        // debug_break();
        Simp.clear_render_target(0, 0, 0, 1);
        Simp.set_shader_for_color();
        draw_rect :: (image: * Simp.Texture, pos: Vector2, CAMERA_SCALE: float, theta: float, w: float, h: float) {
            Simp.set_shader_for_images(image);
            p := pos / CAMERA_SCALE;
            rw := v2(xx cos(theta) * w / CAMERA_SCALE / 2, xx sin(theta) * w / CAMERA_SCALE / 2);
            rh := v2(xx -sin(theta) * h / CAMERA_SCALE / 2, xx cos(theta) * h / CAMERA_SCALE / 2);
            p0 := (p - rw - rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p1 := (p + rw - rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p2 := (p + rw + rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            p3 := (p - rw + rh) * v2(xx window_width, xx window_width) + v2(xx(window_width / 2), xx(window_height / 2));
            Simp.immediate_quad(p0, p1, p2, p3);
            Simp.immediate_flush();
        }
        draw_rect(*stickman, guypos, CAMERA_SCALE, 0, 1, 1);
        draw_rect(*cursor, mouse_pos, CAMERA_SCALE, xx fmod(get_time(), 1) * TAU, 1, 1);
        draw_rect(*sword, guypos + sword_vector, CAMERA_SCALE, atan2(sword_vector.y, sword_vector.x), 2, 1);

        Simp.swap_buffers(window);
    }
}

#run {
    WR :: #import "Windows_Resources";
    // WR.disable_runtime_console();
}