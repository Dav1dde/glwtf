module glwtf.window;


private {
    import glwtf.glfw;
    import glwtf.util : DefaultAA;
    import glwtf.input : BaseGLFWEventHandler;
    import glwtf.exception : WindowException;

    import std.string : toStringz;
    import std.exception : enforceEx;
    import std.functional : curry;
}


struct Rect {
    int x;
    int y;
}

private string set_hint_property(string target, string name, bool getter=false) {
    string ret = `@property void ` ~ name ~ `(int hint) {
                      set_hint(` ~ target ~ `, hint);
                  }`;

    if(getter) {
        ret ~=   `@property int ` ~ name ~ `() {
                      return get_param(` ~ target ~ `);
                  }`;
    }

    return ret;
}


class Window : BaseGLFWEventHandler {
    debug {
        private void* _window;

        @property void* window() {
            assert(_window !is null, "no window created yet!");
            return _window;
        }
        @property void window(void* window) {
            _window = window;
        }
    } else {
        void* window;
    }
    protected DefaultAA!(bool, int, false) keymap;
    protected DefaultAA!(bool, int, false) mousemap;

    this() {
        on_key_down.connect(&_on_key_down);
        on_key_up.connect(&_on_key_up);
        on_mouse_button_down.connect(&_on_mouse_button_down);
        on_mouse_button_up.connect(&_on_mouse_button_up);
    }

    this(void* window) {
        this.window = window;
        register_callbacks(window);
    }

    void set_hint(int target, int hint) {
        glfwWindowHint(target, hint);
    }

    mixin(set_hint_property("GLFW_RED_BITS", "red_bits"));
    mixin(set_hint_property("GLFW_GREEN_BITS", "green_bits"));
    mixin(set_hint_property("GLFW_BLUE_BITS", "blue_bits"));
    mixin(set_hint_property("GLFW_ALPHA_BITS", "alpha_bits"));
    mixin(set_hint_property("GLFW_DEPTH_BITS", "depth_bits"));
    mixin(set_hint_property("GLFW_STENCIL_BITS", "stencil_bits"));
    mixin(set_hint_property("GLFW_ACCUM_RED_BITS", "accum_red_bits"));
    mixin(set_hint_property("GLFW_ACCUM_GREEN_BITS", "accum_green_bits"));
    mixin(set_hint_property("GLFW_ACCUM_BLUE_BITS", "accum_blue_bits"));
    mixin(set_hint_property("GLFW_ACCUM_ALPHA_BITS", "accum_alpha_bits"));
    mixin(set_hint_property("GLFW_AUX_BUFFERS", "aux_buffers"));
    mixin(set_hint_property("GLFW_STEREO", "stereo"));
    mixin(set_hint_property("GLFW_SAMPLES", "samples"));
    mixin(set_hint_property("GLFW_SRGB_CAPABLE", "srgb_capable"));
    mixin(set_hint_property("GLFW_CLIENT_API", "client_api", true));
    mixin(set_hint_property("GLFW_OPENGL_API", "opengl_api"));
    mixin(set_hint_property("GLFW_CONTEXT_VERSION_MAJOR", "context_version_major", true));
    mixin(set_hint_property("GLFW_CONTEXT_VERSION_MINOR", "context_version_minor", true));
    mixin(set_hint_property("GLFW_OPENGL_FORWARD_COMPAT", "opengl_forward_compat", true));
    mixin(set_hint_property("GLFW_OPENGL_DEBUG_CONTEXT", "opengl_debug_context", true));
    mixin(set_hint_property("GLFW_OPENGL_PROFILE", "opengl_profile", true));
    mixin(set_hint_property("GLFW_CONTEXT_ROBUSTNESS", "context_robustness", true));
    mixin(set_hint_property("GLFW_RESIZABLE", "resizable", true));
    mixin(set_hint_property("GLFW_VISIBLE", "visible", true));
    mixin(set_hint_property("GLFW_POSITION_X", "position_x", true));
    mixin(set_hint_property("GLFW_POSITION_Y", "position_y", true));

    void create(int width, int height, string title, void* monitor = null, void* share = null) {
        window = glfwCreateWindow(width, height, title.toStringz(), monitor, share);
        enforceEx!WindowException(window !is null, "Failed to create GLFW Window");
        register_callbacks(window);
    }

    void destroy() {
        glfwDestroyWindow(window);
    }

    @property void title(string title) {
        glfwSetWindowTitle(window, title.toStringz());
    }

    @property void size(Rect rect) {
        glfwSetWindowSize(window, rect.x, rect.y);
    }

    @property Rect size() {
        Rect rect;
        glfwGetWindowSize(window, &rect.x, &rect.y);
        return rect;
    }

    void iconify() {
        glfwIconifyWindow(window);
    }

    void restore() {
        glfwRestoreWindow(window);
    }

//     void show() {
//         glfwShowWindow(window);
//     }
// 
//     void hide() {
//         glfwHideWindow(window);
//     }

    int get_param(int param) {
        return glfwGetWindowParam(window, param);
    }

    void set_input_mode(int mode, int value) {
        glfwSetInputMode(window, mode, value);
    }

    int get_input_mode(int mode) {
        return glfwGetInputMode(window, mode);
    }

    void make_context_current() {
        glfwMakeContextCurrent(window);
    }

    void swap_buffers() {
        glfwSwapBuffers(window);
    }

    // callbacks ------
    // window
    bool delegate() on_close;

    override bool _on_close() {
        if(on_close !is null) {
            return on_close();
        }
        
        return true;
    }

    // input
    protected void _on_key_down(int key) {
        keymap[key] = true;
    }
    protected void _on_key_up(int key) {
        keymap[key] = false;
    }
    
    protected void _on_mouse_button_down(int button) {
        mousemap[button] = true;
    }
    protected void _on_mouse_button_up(int button) {
        mousemap[button] = false;
    }

    bool is_key_down(int key) {
        return keymap[key];
    }

    bool is_mouse_down(int button) {
        return mousemap[button];
    }
}