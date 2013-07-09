// Written in the D programming language.

/**
 * Signals and Slots are an implementation of the Observer Pattern.
 * Essentially, when a Signal is emitted, a list of connected Observers
 * (called slots) are called.
 *
 * There have been several D implementations of Signals and Slots.
 * This version makes use of several new features in D, which make
 * using it simpler and less error prone. In particular, it is no
 * longer necessary to instrument the slots.
 *
 * References:
 *      $(LINK2 http://scottcollins.net/articles/a-deeper-look-at-_signals-and-slots.html, A Deeper Look at Signals and Slots)$(BR)
 *      $(LINK2 http://en.wikipedia.org/wiki/Observer_pattern, Observer pattern)$(BR)
 *      $(LINK2 http://en.wikipedia.org/wiki/Signals_and_slots, Wikipedia)$(BR)
 *      $(LINK2 http://boost.org/doc/html/$(SIGNALS).html, Boost Signals)$(BR)
 *      $(LINK2 http://doc.trolltech.com/4.1/signalsandslots.html, Qt)$(BR)
 *
 *      There has been a great deal of discussion in the D newsgroups
 *      over this, and several implementations:
 *
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/announce/signal_slots_library_4825.html, signal slots library)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/Signals_and_Slots_in_D_42387.html, Signals and Slots in D)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/Dynamic_binding_--_Qt_s_Signals_and_Slots_vs_Objective-C_42260.html, Dynamic binding -- Qt's Signals and Slots vs Objective-C)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/Dissecting_the_SS_42377.html, Dissecting the SS)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/dwt/about_harmonia_454.html, about harmonia)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/announce/1502.html, Another event handling module)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/41825.html, Suggestion: signal/slot mechanism)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/13251.html, Signals and slots?)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/10714.html, Signals and slots ready for evaluation)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/1393.html, Signals &amp; Slots for Walter)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/28456.html, Signal/Slot mechanism?)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/19470.html, Modern Features?)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/16592.html, Delegates vs interfaces)$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/16583.html, The importance of component programming (properties, signals and slots, etc))$(BR)
 *      $(LINK2 http://www.digitalmars.com/d/archives/16368.html, signals and slots)$(BR)
 *
 * Bugs:
 *      Not safe for multiple threads operating on the same signals
 *      or slots.
 *
 *      Safety of handlers is not yet enforced
 * Macros:
 *      WIKI = Phobos/StdSignals
 *      SIGNALS=signals
 *
 * Copyright: Copyright Digital Mars 2000 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright),
 *            Johannes Pfau, Andrej Mitrovic
 */
/*          Copyright Digital Mars 2000 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

// https://github.com/AndrejMitrovic/new_signals

module glwtf.signals;

import std.algorithm;
import std.container;
import std.functional;
import std.range;
import std.traits;
import std.exception;
import std.stdio;
import std.typetuple;

/**
 * This Signal struct is an implementation of the Observer pattern.
 *
 * All D callable types (functions, delegates, structs with opCall,
 * classes with opCall) can be registered with a signal. When the signal
 * occurs all assigned callables are called.
 *
 * Structs with opCall are only supported if they're passed by pointer. These
 * structs are then expected to be allocated on the heap.
 *
 * Delegates to struct instances or nested functions are supported. However you
 * have to make sure to disconnect these delegates from the Signal before
 * they go out of scope.
 *
 * The return type of the handlers must be void or bool. If the return
 * type is bool and the handler returns false the remaining handlers are
 * not called. If true is returned or the type is void the remaining
 * handlers are called.
 */
struct Signal(ParamTypes...)
{
    /**
     * Set to false to disable signal emission
     */
    bool enabled = true;

    /**
     * Check whether a handler is already connected
     */
    bool isConnected(T)(T handler)
        if (isHandler!(T, ParamTypes))
    {
        Callable call = getCallable(handler);
        return !find(handlers[], call).empty;
    }

    /**
     * Add a handler to the list of handlers to be called when emit() is called.
     * The handler is added at the end of the list.
     */
    T connect(T)(T handler)
        if (isHandler!(T, ParamTypes))
    {
        Callable call = getCallable(handler);
        assert(find(handlers[], call).empty, "Handler is already registered!");
        handlers.stableInsertAfter(handlers[], call);
        return handler;
    }

    /**
     * Add a handler to the list of handlers to be called when emit() is called.
     * Add this handler at the top of the list, so it will be called before all
     * other handlers.
     */
    T connectFirst(T)(T handler)
        if (isHandler!(T, ParamTypes))
    {
        Callable call = getCallable(handler);
        assert(find(handlers[], call).empty, "Handler is already registered!");
        handlers.stableInsertFront(call);
        return handler;
    }

    /**
     * Add a handler to be called after another handler.
     * Params:
     *     afterThis = The new attached handler will be called after this handler
     *     handler = The handler to be attached
     */
    T connectAfter(T, U)(T afterThis, U handler)
       if (isHandler!(T, ParamTypes) && isHandler!(U, ParamTypes))
    {
        Callable after = getCallable(afterThis);
        Callable call = getCallable(handler);
        auto location = find(handlers[], after);

        if (location.empty)  // afterThis not found
        {
            // always connect before manager
            return connectFirst(handler);
        }
        else
        {
            assert(find(handlers[], call).empty, "Handler is already registered!");
            handlers.stableInsertAfter(take(location, 1), call);
            return handler;
        }
    }

    /**
     * Add a handler to be called before another handler.
     * Params:
     *     beforeThis = The new attached handler will be called after this handler
     *     handler = The handler to be attached
     */
    T connectBefore(T, U)(T beforeThis, U handler)
        if (isHandler!(T, ParamTypes) && isHandler!(U, ParamTypes))
    {
        Callable before = getCallable(beforeThis);
        Callable call = getCallable(handler);
        auto location = find(handlers[], before);
        if (location.empty)
        {
             throw new Exception("Handler 'beforeThis' is not registered!");
        }
        assert(find(handlers[], call).empty, "Handler is already registered!");

        //not exactly fast
        size_t length = walkLength(handlers[]);
        size_t pos = walkLength(location);
        size_t new_location = length - pos;
        location = handlers[];
        if (new_location == 0)
            handlers.stableInsertFront(call);
        else
            handlers.stableInsertAfter(take(location, new_location), call);
        return handler;
    }

    /**
     * Remove a handler from the list of handlers to be called when emit() is called.
     */
    T disconnect(T)(T handler)
        if (isHandler!(T, ParamTypes))
    {
        Callable call = getCallable(handler);
        auto pos = find(handlers[], call);
        if (pos.empty)
        {
            throw new Exception("Handler is not connected");
        }
        handlers.stableLinearRemove(take(pos, 1));
        return handler;
    }

    /**
     * Remove all handlers from the signal
     */
    void clear()
    {
        handlers.clear();
    }

    /**
     * Calculate the number of registered handlers
     */
    size_t calculateLength()
    {
        return walkLength(handlers[]);
    }

    /**
        All the handler types that can be connected to this signal instance.
        The ones which return a boolean can stop the signal propagation.
    */
    private alias FuncVoid  = void function(ParamTypes);
    private alias FuncBool  = bool function(ParamTypes);
    private alias DelegVoid = void delegate(ParamTypes);
    private alias DelegBool = bool delegate(ParamTypes);

    /**
        Emit the signal to all connected callbacks.
        It returns true only if all handlers returned true,
        it will return false if the signal is either not
        enabled, or if one of boolean return callbacks
        has returned false to stop the signal from propagating.
    */
    bool emit(ParamTypes params)
    {
        if (!enabled)
            return false;

        foreach(callable; handlers[])
        {
            if (callable.deleg !is null)
            {
                if (callable.returnsBool)
                {
                    DelegBool del = cast(DelegBool)callable.deleg;
                    if(!del(params))
                        return false;
                }
                else
                {
                    DelegVoid del = cast(DelegVoid)callable.deleg;
                    del(params);
                }
            }
            else
            if (callable.func !is null)
            {
                if (callable.returnsBool)
                {
                    FuncBool fun = cast(FuncBool)callable.func;
                    if(!fun(params))
                        return false;
                }
                else
                {
                    FuncVoid fun = cast(FuncVoid)callable.func;
                    fun(params);
                }
            }
            else
                enforce(0, "Error: missing signal handler.");
        }

        return true;
    }

    private static struct Callable
    {
        this(T)(T del)
            if (isHandler!(T, ParamTypes))
        {
            this.returnsBool = is(ReturnType!T == bool);

            static if (is(T == class))
            {
                this.deleg = cast(DelegBool)&del.opCall;
            }
            else
            static if (isPointer!T && is(pointerTarget!T == struct))
            {
                this.deleg = cast(DelegBool)&del.opCall;
            }
            else
            static if (isDelegate!T)
            {
                this.deleg = cast(DelegBool)del;
            }
            else
            static if (isFunctionPointer!T)
            {
                this.func = cast(FuncBool)del;
            }
            else
            static assert(0);
        }

        DelegBool deleg;
        FuncBool func;
        bool returnsBool;
    }

    /*
     * Get a Callable for the handler.
     * Handler can be a void function, void delegate, bool
     * function, bool delegate, class with opCall or a pointer to
     * a struct with opCall.
     */
    private Callable getCallable(T)(T handler)
        if (isHandler!(T, ParamTypes))
    {
        return Callable(handler);
    }

    private SList!Callable handlers;
}

///
unittest
{
    Signal!int sig;

    static bool stop(int x) { assert(x == 1); return false; }
    static void crash(int x) { assert(0); }

    sig.connect(&stop);
    sig.connect(&crash);
    sig.emit(1);
}

//unit tests
unittest
{
    int val;
    string text;
    @safe void handler(int i, string t)
    {
        val = i;
        text = t;
    }
    @safe static void handler2(int i, string t)
    {
    }

    Signal!(int, string) onTest;
    onTest.connect(&handler);
    onTest.connect(&handler2);
    onTest.emit(1, "test");
    assert(val == 1);
    assert(text == "test");
    onTest.emit(99, "te");
    assert(val == 99);
    assert(text == "te");
}

unittest
{
    @safe void handler() {}
    Signal!() onTest;
    onTest.connect(&handler);
    bool thrown = false;
    try
        onTest.connect(&handler);
    catch(Throwable)
        thrown = true;

    assert(thrown);
}

unittest
{
    @safe void handler() { }
    Signal!() onTest;
    onTest.connect(&handler);
    onTest.disconnect(&handler);
    onTest.connect(&handler);
    onTest.emit();
}

unittest
{
    bool called = false;
    @safe void handler() { called = true; }
    Signal!() onTest;
    onTest.connect(&handler);
    onTest.disconnect(&handler);
    onTest.connect(&handler);
    onTest.emit();
    assert(called);
}

unittest
{
    class handler
    {
        @safe void opCall(int i) {}
    }

    struct handler2
    {
        @safe void opCall(int i) {}
    }
    Signal!(int) onTest;
    onTest.connect(new handler);
    auto h = onTest.connect(new handler2);
    onTest.emit(0);
    onTest.disconnect(h);
}

unittest
{
    __gshared bool called = false;

    struct A
    {
        string payload;

        @trusted void opCall(float f, string s)
        {
            assert(payload == "payload");
            assert(f == 0.1234f);
            assert(s == "test call");
            called = true;
        }
    }

    A* a = new A();
    a.payload = "payload";

    Signal!(float, string) onTest;
    onTest.connect(a);
    onTest.emit(0.1234f, "test call");
    assert(called);
}

unittest
{
    __gshared bool called;
    struct A
    {
        string payload;
        @trusted void opCall(float f, string s)
        {
            assert(payload == "payload 2");
            called = true;
        }
    }

    A* a = new A();
    a.payload = "payload";

    Signal!(float, string) onTest;
    onTest.connect(a);
    A* b = new A();
    b.payload = "payload 2";
    onTest.connect(b);
    onTest.disconnect(a);
    onTest.emit(0.1234f, "test call");
    assert(called);
}

unittest
{
    struct A
    {
        @safe void opCall() {}
    }
    A* a = new A();

    Signal!() onTest;
    onTest.connect(a);
    bool thrown = false;
    try
        onTest.connect(a);
    catch(Throwable)
        thrown = true;

    assert(thrown);
}

unittest
{
    struct A
    {
        @safe void opCall() {}
    }
    A* a = new A();

    Signal!() onTest;
    onTest.connect(a);
    onTest.disconnect(a);
    bool thrown = false;
    try
        onTest.disconnect(a);
    catch(Throwable)
        thrown = true;

    assert(thrown);
}

unittest
{
    struct A
    {
        @safe void opCall() {}
    }
    A* a = new A();

    Signal!() onTest;
    bool thrown = false;
    try
        onTest.disconnect(a);
    catch(Throwable)
        thrown = true;

    assert(thrown);
}

unittest
{
    bool secondCalled = false;
    @safe bool first(int i) {return false;}
    @safe void second(int i) {secondCalled = true;}
    Signal!(int) onTest;
    onTest.connect(&first);
    onTest.connect(&second);
    onTest.emit(0);
    assert(!secondCalled);
    onTest.disconnect(&first);
    onTest.connect(&first);
    onTest.emit(0);
    assert(secondCalled);
}

unittest
{
    @safe void second(int i) {}
    Signal!(int) onTest;
    auto t1 = onTest.getCallable(&second);
    auto t2 = onTest.getCallable(&second);
    auto t3 = onTest.getCallable(&second);
    assert(t1 == t2);
    assert(t2 == t3);
}

unittest
{
    bool called = false;
    @safe void handler() { called = true; }
    Signal!() onTest;
    onTest.connect(&handler);
    onTest.emit();
    assert(called);
    called = false;
    onTest.enabled = false;
    onTest.emit();
    assert(!called);
    onTest.enabled = true;
    onTest.emit();
    assert(called);
}

unittest
{
    @safe void handler() {}
    Signal!() onTest;
    assert(!onTest.isConnected(&handler));
    onTest.connect(&handler);
    assert(onTest.isConnected(&handler));
    onTest.emit();
    assert(onTest.isConnected(&handler));
    onTest.disconnect(&handler);
    assert(!onTest.isConnected(&handler));
    onTest.emit();
    assert(!onTest.isConnected(&handler));
}

unittest
{
    bool firstCalled, secondCalled, thirdCalled;
    @safe void handler1() {firstCalled = true;}
    @safe void handler2()
    {
        secondCalled = true;
        assert(firstCalled);
        assert(thirdCalled);
    }
    @safe void handler3()
    {
        thirdCalled = true;
        assert(firstCalled);
        assert(!secondCalled);
    }
    Signal!() onTest;
    onTest.connect(&handler1);
    onTest.connect(&handler2);
    auto h = onTest.connectAfter(&handler1, &handler3);
    assert(h == &handler3);
    onTest.emit();
    assert(firstCalled && secondCalled && thirdCalled);
}

unittest
{
    bool firstCalled, secondCalled;
    @safe void handler1() {firstCalled = true;}
    @safe void handler2()
    {
        secondCalled = true;
        assert(firstCalled);
    }
    Signal!() onTest;
    onTest.connect(&handler2);
    onTest.connectFirst(&handler1);
    onTest.emit();
    assert(firstCalled && secondCalled);
}

unittest
{
    bool firstCalled, secondCalled, thirdCalled;
    @safe void handler1() {firstCalled = true;}
    @safe void handler2()
    {
        secondCalled = true;
        assert(firstCalled);
        assert(!thirdCalled);
    }
    @safe void handler3()
    {
        thirdCalled = true;
        assert(firstCalled);
        assert(secondCalled);
    }
    Signal!() onTest;
    onTest.connect(&handler2);
    auto h = onTest.connectAfter(&handler2, &handler3);
    assert(h == &handler3);
    auto h2 = onTest.connectBefore(&handler2, &handler1);
    assert(h2 == &handler1);
    onTest.emit();
    assert(firstCalled && secondCalled && thirdCalled);
    firstCalled = secondCalled = thirdCalled = false;
    onTest.disconnect(h);
    onTest.disconnect(h2);
    onTest.disconnect(&handler2);
    onTest.connect(&handler1);
    onTest.connect(&handler3);
    onTest.connectBefore(&handler3, &handler2);
    onTest.emit();
    assert(firstCalled && secondCalled && thirdCalled);
}

unittest
{
    @safe void handler() {}
    Signal!() onTest;
    assert(onTest.calculateLength() == 0);
    onTest.connect(&handler);
    assert(onTest.calculateLength() == 1);
    onTest.clear();
    assert(onTest.calculateLength() == 0);
    onTest.emit();
}

/** Callbacks can only have these return types. */
private alias CallbackReturnTypes = TypeTuple!(void, bool);

/** Check whether $(D T) is a handler function which can be called with the $(D Types). */
private template isHandler(T, Types...)
    if (isSomeFunction!T)
{
    enum bool isHandler = is(typeof(T.init(Types.init))) && isOneOf!(ReturnType!T, CallbackReturnTypes);
}

/// function pointer
unittest
{
    static void vc0() { }
    static void vc1(int) { }
    static void vc2(int, float) { }

    static bool bc0() { return false; }
    static bool bc1(int) { return false; }
    static bool bc2(int, float) { return false; }

    static assert(isHandler!(typeof(&vc0)));
    static assert(isHandler!(typeof(&vc1), int));
    static assert(isHandler!(typeof(&vc2), int, float));
    static assert(isHandler!(typeof(&bc0)));
    static assert(isHandler!(typeof(&bc1), int));
    static assert(isHandler!(typeof(&bc2), int, float));

    static assert(!isHandler!(typeof(&vc1), string));
    static assert(!isHandler!(typeof(&vc2), string, float));
    static assert(!isHandler!(typeof(&bc1), string));
    static assert(!isHandler!(typeof(&bc2), string, float));

    static assert(!isHandler!(typeof(&vc0), int));
    static assert(!isHandler!(typeof(&vc1)));
    static assert(!isHandler!(typeof(&vc2)));
    static assert(!isHandler!(typeof(&bc0), int));
    static assert(!isHandler!(typeof(&bc1)));
    static assert(!isHandler!(typeof(&bc2)));

    // only void and bool return types allowed
    static string sc1(int) { return ""; }
    static assert(!isHandler!(typeof(&sc1), int));
}

/// delegate
unittest
{
    int x;
    void vc0() { x = 1; }
    void vc1(int) { x = 1; }
    void vc2(int, float) { x = 1; }

    bool bc0() { x = 1; return false; }
    bool bc1(int) { x = 1; return false; }
    bool bc2(int, float) { x = 1; return false; }

    static assert(isHandler!(typeof(&vc0)));
    static assert(isHandler!(typeof(&vc1), int));
    static assert(isHandler!(typeof(&vc2), int, float));
    static assert(isHandler!(typeof(&bc0)));
    static assert(isHandler!(typeof(&bc1), int));
    static assert(isHandler!(typeof(&bc2), int, float));

    static assert(!isHandler!(typeof(&vc1), string));
    static assert(!isHandler!(typeof(&vc2), string, float));
    static assert(!isHandler!(typeof(&bc1), string));
    static assert(!isHandler!(typeof(&bc2), string, float));

    static assert(!isHandler!(typeof(&vc0), int));
    static assert(!isHandler!(typeof(&vc1)));
    static assert(!isHandler!(typeof(&vc2)));
    static assert(!isHandler!(typeof(&bc0), int));
    static assert(!isHandler!(typeof(&bc1)));
    static assert(!isHandler!(typeof(&bc2)));

    // only void and bool return types allowed
    string sc1(int) { x = 1; return ""; }
    static assert(!isHandler!(typeof(&sc1), int));
}

/** Check whether $(D T) is a pointer to a struct with an $(D opCall) function which can be called with the $(D Types). */
private template isHandler(T, Types...)
    if (isPointer!T && is(pointerTarget!T == struct))
{
    enum bool isHandler = is(typeof(pointerTarget!T.init.opCall(Types.init)))
                          && isOneOf!(ReturnType!T, CallbackReturnTypes);
}

/// ditto
private template isHandler(T, Types...)
    if (is(T == struct))
{
    enum bool isHandler = false;
}

/// struct opCall
unittest
{
    static struct VC0 { void opCall() { } }
    static struct VC1 { void opCall(int) { } }
    static struct VC2 { void opCall(int, float) { } }

    static struct BC0 { bool opCall() { return false; } }
    static struct BC1 { bool opCall(int) { return false; } }
    static struct BC2 { bool opCall(int, float) { return false; } }

    VC0 vc0; VC1 vc1; VC2 vc2;
    BC0 bc0; BC1 bc1; BC2 bc2;

    static assert(isHandler!(typeof(&vc0)));
    static assert(isHandler!(typeof(&vc1), int));
    static assert(isHandler!(typeof(&vc2), int, float));
    static assert(isHandler!(typeof(&bc0)));
    static assert(isHandler!(typeof(&bc1), int));
    static assert(isHandler!(typeof(&bc2), int, float));

    // only pointers to struct instances allowed for opCall
    static assert(!isHandler!(typeof(vc0)));
    static assert(!isHandler!(typeof(vc1), int));
    static assert(!isHandler!(typeof(vc2), int, float));
    static assert(!isHandler!(typeof(bc0)));
    static assert(!isHandler!(typeof(bc1), int));
    static assert(!isHandler!(typeof(bc2), int, float));

    static assert(!isHandler!(typeof(&vc1), string));
    static assert(!isHandler!(typeof(&vc2), string, float));
    static assert(!isHandler!(typeof(&bc1), string));
    static assert(!isHandler!(typeof(&bc2), string, float));

    static assert(!isHandler!(typeof(&vc0), int));
    static assert(!isHandler!(typeof(&vc1)));
    static assert(!isHandler!(typeof(&vc2)));
    static assert(!isHandler!(typeof(&bc0), int));
    static assert(!isHandler!(typeof(&bc1)));
    static assert(!isHandler!(typeof(&bc2)));

    // only void and bool return types allowed
    static struct SC1 { string opCall(int) { return ""; } }
    SC1 sc1;
    static assert(!isHandler!(typeof(&sc1), int));
}

/** Check whether $(D T) is a class with an $(D opCall) function which can be called with the $(D Types). */
private template isHandler(T, Types...)
    if (is(T == class))
{
    static if (is(typeof(T.init.opCall(Types.init))))
    {
        enum bool isHandler = isOneOf!(typeof(T.init.opCall(Types.init)), CallbackReturnTypes);
    }
    else
    {
        enum bool isHandler = false;
    }
}

/// class opCall
unittest
{
    static class VC0 { void opCall() { } }
    static class VC1 { void opCall(int) { } }
    static class VC2 { void opCall(int, float) { } }

    static class BC0 { bool opCall() { return false; } }
    static class BC1 { bool opCall(int) { return false; } }
    static class BC2 { bool opCall(int, float) { return false; } }

    VC0 vc0; VC1 vc1; VC2 vc2;
    BC0 bc0; BC1 bc1; BC2 bc2;

    static assert(isHandler!(typeof(vc0)));
    static assert(isHandler!(typeof(vc1), int));
    static assert(isHandler!(typeof(vc2), int, float));
    static assert(isHandler!(typeof(bc0)));
    static assert(isHandler!(typeof(bc1), int));
    static assert(isHandler!(typeof(bc2), int, float));

    static assert(!isHandler!(typeof(vc1), string));
    static assert(!isHandler!(typeof(vc2), string, float));
    static assert(!isHandler!(typeof(bc1), string));
    static assert(!isHandler!(typeof(bc2), string, float));

    static assert(!isHandler!(typeof(vc0), int));
    static assert(!isHandler!(typeof(vc1)));
    static assert(!isHandler!(typeof(vc2)));
    static assert(!isHandler!(typeof(bc0), int));
    static assert(!isHandler!(typeof(bc1)));
    static assert(!isHandler!(typeof(bc2)));

    // only void and bool return types allowed
    static struct SC1 { string opCall(int) { return ""; } }
    SC1 sc1;
    static assert(!isHandler!(typeof(&sc1), int));
}

/**
    Checks whether $(D Target) matches any $(D Types).
*/
template isOneOf(Target, Types...)
{
    static if (Types.length > 1)
    {
        enum bool isOneOf = isOneOf!(Target, Types[0]) || isOneOf!(Target, Types[1 .. $]);
    }
    else static if (Types.length == 1)
    {
        enum bool isOneOf = is(Unqual!Target == Unqual!(Types[0]));
    }
    else
    {
        enum bool isOneOf = false;
    }
}

///
unittest
{
    static assert(isOneOf!(int, float, string, const(int)));
    static assert(isOneOf!(const(int), float, string, int));
    static assert(!isOneOf!(int, float, string));
}
