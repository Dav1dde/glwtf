module glwtf.window;


private {
    import glwtf.glfw;
    import glwtf.util : DefaultAA;
    import glwtf.input : BaseGLFWEventHandler;
    import glwtf.exception : WindowException;

    import std.string : toStringz;
    import std.exception : enforceEx;
}


struct Rect {
    int x;
    int y;
}

class Window : BaseGLFWEventHandler {
    void* window;
    protected DefaultAA!(bool, int, false) keymap;
    protected DefaultAA!(bool, int, false) mousemap;

    this() {
        on_key_down.connect(&_on_key_down);
        on_key_up.connect(&_on_key_up);
        on_mouse_button_down.connect(&_on_mouse_button_down);
        on_mouse_button_up.connect(&_on_mouse_button_up);
    }

    void set_hint(int target, int hint) {
        glfwWindowHint(target, hint);
    }

    void create(int width, int height, int mode, string title, void* share = null) {
        window = glfwCreateWindow(width, height, mode, title.toStringz(), share);
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

    @property void position(Rect rect) {
        glfwSetWindowPos(window, rect.x, rect.y);
    }

    @property Rect position() {
        Rect rect;
        glfwGetWindowPos(window, &rect.x, &rect.y);
        return rect;
    }

    void iconify() {
        glfwIconifyWindow(window);
    }

    void restore() {
        glfwRestoreWindow(window);
    }

    void show() {
        glfwShowWindow(window);
    }

    void hide() {
        glfwHideWindow(window);
    }

    int get_param(int param) {
        return glfwGetWindowParam(window, param);
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
}