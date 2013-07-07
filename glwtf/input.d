module glwtf.input;


private {
    import glwtf.glfw;
    import glwtf.util : DefaultAA;

    import std.conv : to;
    import std.signals;
}

AEventHandler cast_userptr(GLFWwindow* window)
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
    void window_resize_callback(GLFWwindow* window, int width, int height) {
        AEventHandler ae = cast_userptr(window);

        ae.on_resize.emit(width, height);
    }

    void window_close_callback(GLFWwindow* window) {
        AEventHandler ae = cast_userptr(window);

        bool close = cast(int)ae._on_close();
        if(close) {
            ae.on_closing.emit();
        } else {
            glfwSetWindowShouldClose(window, 0);
        }
    }

    void window_refresh_callback(GLFWwindow* window) {
        AEventHandler ae = cast_userptr(window);

        ae.on_refresh.emit();
    }

    void window_focus_callback(GLFWwindow* window, int focused) {
        AEventHandler ae = cast_userptr(window);

        ae.on_focus.emit(focused == GLFW_PRESS);
    }

    void window_iconify_callback(GLFWwindow* window, int iconified) {
        AEventHandler ae = cast_userptr(window);

        ae.on_iconify.emit(iconified == GLFW_PRESS); // TODO: test this
    }

    // user input //
    void key_callback(GLFWwindow* window, int key, int scancode, int state, int modifier) {
        AEventHandler ae = cast_userptr(window);

        if(state == GLFW_PRESS || GLFW_REPEAT) {
            ae.on_key_down.emit(key, scancode, modifier);
        } else {
            ae.on_key_up.emit(key, scancode, modifier);
        }
    }

    void char_callback(GLFWwindow* window, uint c) {
        AEventHandler ae = cast_userptr(window);

        ae.on_char.emit(cast(dchar)c);
    }

    void mouse_button_callback(GLFWwindow* window, int button, int state, int modifier) {
        AEventHandler ae = cast_userptr(window);

        if(state == GLFW_PRESS) {
            ae.on_mouse_button_down.emit(button, modifier);
        } else {
            ae.on_mouse_button_up.emit(button, modifier);
        }
    }

    void cursor_pos_callback(GLFWwindow* window, double x, double y) {
        AEventHandler ae = cast_userptr(window);

        ae.on_mouse_pos.emit(x, y);
    }

    void scroll_callback(GLFWwindow* window, double xoffset, double yoffset) {
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
    mixin Signal!(int, int, int) on_key_down;
    mixin Signal!(int, int, int) on_key_up;
    mixin Signal!(dchar) on_char;
    mixin Signal!(int, int) on_mouse_button_down;
    mixin Signal!(int, int) on_mouse_button_up;
    mixin Signal!(double, double) on_mouse_pos;
    mixin Signal!(double, double) on_scroll;
}

private class SignalWrapper(Args...) {
    mixin Signal!(Args);

    static auto new_() {
        return new SignalWrapper!(Args);
    }
}

class BaseGLFWEventHandler : AEventHandler {
    DefaultAA!(SignalWrapper!(), int, SignalWrapper!().new_) single_key_down;
    DefaultAA!(SignalWrapper!(), int, SignalWrapper!().new_) single_key_up;
    DefaultAA!(SignalWrapper!(), dchar, SignalWrapper!().new_) single_char;

    protected DefaultAA!(bool, int, false) keymap;
    protected DefaultAA!(bool, int, false) mousemap;

    this() {
        on_key_down.connect(&_on_key_down);
        on_key_up.connect(&_on_key_up);
        on_mouse_button_down.connect(&_on_mouse_button_down);
        on_mouse_button_up.connect(&_on_mouse_button_up);
    }

    package void register_callbacks(GLFWwindow* window) {
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

    protected void _on_key_down(int key, int scancode, int modifier) {
        keymap[key] = true;
        single_key_down[key].emit();
    }

    protected void _on_key_up(int key, int scancode, int modifier) {
        keymap[key] = false;
        single_key_up[key].emit();
    }

    protected void _on_char(dchar c) {
        single_char[c].emit();
    }

    protected void _on_mouse_button_down(int button, int modifier) {
        mousemap[button] = true;
    }
    protected void _on_mouse_button_up(int button, int modifier) {
        mousemap[button] = false;
    }

    bool is_key_down(int key) {
        return keymap[key];
    }

    bool is_mouse_down(int button) {
        return mousemap[button];
    }
}
