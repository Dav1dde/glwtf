module glwtf.input;


private {
    import glwtf.glfw;
    
    import std.conv : to;
    import std.signals;
}

AEventHandler cast_userptr(void* window)
    out (result) { assert(result !is null, "glfwGetWindowUserPointer returned null"); }
    body {
        void* user_ptr = glfwGetWindowUserPointer(window);
        return cast(AEventHandler)user_ptr;
    }


private void function(int, string) glfw_error_callback;

void register_glfw_error_callback(void function(int, string) cb) {
    glfw_error_callback = cb;

    glfwSetErrorCallback(&error_callback);
}

extern(C) {
    // window events //
    void window_resize_callback(void* window, int width, int height) {
        AEventHandler ae = cast_userptr(window);

        ae.on_resize.emit(width, height);
    }

    int window_close_callback(void* window) {
        AEventHandler ae = cast_userptr(window);

        bool close = cast(int)ae._on_close();
        if(close) {
            ae.on_closing.emit();
        }
        return close;
    }

    void window_refresh_callback(void* window) {
        AEventHandler ae = cast_userptr(window);

        ae.on_refresh.emit();
    }

    void window_focus_callback(void* window, int focused) {
        AEventHandler ae = cast_userptr(window);

        ae.on_focus.emit(focused == GLFW_PRESS);
    }

    void window_iconify_callback(void* window, int iconified) {
        AEventHandler ae = cast_userptr(window);

        ae.on_iconify.emit(iconified == GLFW_PRESS); // TODO: test this
    }

    // user input //
    void key_callback(void* window, int key, int state) {
        AEventHandler ae = cast_userptr(window);

        if(state == GLFW_PRESS) {
            ae.on_key_down.emit(key);
        } else {
            ae.on_key_up.emit(key);
        }
    }

    void char_callback(void* window, int c) {
        AEventHandler ae = cast_userptr(window);

        ae.on_char.emit(cast(dchar)c);
    }

    void mouse_button_callback(void* window, int button, int state) {
        AEventHandler ae = cast_userptr(window);

        if(state == GLFW_PRESS) {
            ae.on_mouse_button_down.emit(button);
        } else {
            ae.on_mouse_button_up.emit(button);
        }
    }

    void cursor_pos_callback(void* window, int x, int y) {
        AEventHandler ae = cast_userptr(window);

        ae.on_mouse_pos.emit(x, y);
    }

    void scroll_callback(void* window, double xoffset, double yoffset) {
        AEventHandler ae = cast_userptr(window);

        ae.on_scroll.emit(xoffset, yoffset);
    }

    // misc //
    void error_callback(int errno, const(char)* error) {
        glfw_error_callback(errno, to!string(error));
    }
}

abstract class AEventHandler {
    // window
    mixin Signal!(int, int) on_resize;
    mixin Signal!() on_closing;
    mixin Signal!() on_refresh;
    mixin Signal!(bool) on_focus;
    mixin Signal!(bool) on_iconify;
    
    bool _on_close() { return true; }

    // input
    mixin Signal!(int) on_key_down;
    mixin Signal!(int) on_key_up;
    mixin Signal!(dchar) on_char;
    mixin Signal!(int) on_mouse_button_down;
    mixin Signal!(int) on_mouse_button_up;
    mixin Signal!(int, int) on_mouse_pos;
    mixin Signal!(double, double) on_scroll;
}

class BaseGLFWEventHandler : AEventHandler {
    package void register_callbacks(void* window) {
        glfwSetWindowUserPointer(window, cast(void *)this);

        glfwSetWindowSizeCallback(window, &window_resize_callback);
        glfwSetWindowCloseCallback(window, &window_close_callback);
        glfwSetWindowRefreshCallback(window, &window_refresh_callback);
        glfwSetWindowFocusCallback(window, &window_focus_callback);
        glfwSetWindowIconifyCallback(window, &window_iconify_callback);

        glfwSetKeyCallback(window, &key_callback);
        glfwSetCharCallback(window, &char_callback);
        glfwSetMouseButtonCallback(window, &mouse_button_callback);
        glfwSetCursorPosCallback(window, &cursor_pos_callback);
        glfwSetScrollCallback(window, &scroll_callback);
    }
}
