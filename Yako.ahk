#Requires AutoHotkey >=v2.1-alpha.9
#Include <AquaHotkeyX>
/**
 * ```
 *  ,-.    ,_~*, /
 *     \ ,´_, ´ /        _,
 *      l (_|, /__   .*´  l\  _@&^""-._o
 *   <_/     `/\  (o)      `*$m^
 * ```
 * https://www.github.com/0w0Demonic/Yako
 * 
 * ---
 * 
 * ### Yako - Forward Windows Messages to AutoHotkey
 * 
 * Yako is a lightweight AutoHotkey v2 library for hooking external applications
 * by overwriting their window procedures via DLL injection. It lets you forward
 * raw Windows messages from other processes directly into your AutoHotkey
 * script, giving you complete control over how they're handled.
 * 
 * ---
 * 
 * ### Core Concept
 * 
 * At its core, Yako injects a custom DLL into a target process and overwrites
 * that window's window procedure (`WndProc`). From there, every window message
 * received by the hooked window is rerouted to your AutoHotkey script, where
 * you can handle it however you like. **Yako turns external windows into
 * controllable endpoints**.
 * 
 * ---
 * 
 * ### How to Use Yako
 * 
 * ```
 * class ExitScriptWhenClosed extends Yako {
 *     class MessageHandler {
 *         static Destroy(Callback) {
 *             this.OnMessage(WM_DESTROY := 0x0002, (this, wParam, lParam) {
 *                 return Callback(this)
 *             })
 *         }
 *         Destroy() {
 *             ToolTip("exiting script...")
 *             SetTimer(() => ExitApp(), -3000)
 *         }
 *     }
 * }
 * ```
 * 
 * 1. **Subclass `Yako`**:
 * 
 * Define a new class in your script that extends the `Yako` base class.
 * This becomes your interface to the hooked window.
 * 
 * ```
 * class ExitScriptWhenClosed extends Yako { ... }
 * ```
 * 
 * 2. **Declare a `MessageHandler` Nested Class**:
 * 
 * Inside your class, declare a nested `class MessageHandler`, which handles
 * all incoming messages.
 * 
 * ```
 * ...
 * class MessageHandler {...}
 * ...
 * ```
 * 
 * - **Static methods** act as registration shims. They define which message
 *   IDs to care about, and how the `wParam` and `lParam` should be converted to
 *   more useful parameters. They should call `.OnMessage(MsgNumber, Callback)`
 *   or similar.
 * 
 * ```
 * ...
 * static Destroy(Callback) { ; accept the function to be called
 *     this.OnMessage(WM_DESTROY := 0x0002, (this, wParam, lParam) {
 *         ; discard `wParam` and `lParam` - they're not needed in this message
 *         Callback(this)
 *     })
 * }
 * ...
 * ```
 * 
 * - **Non-static methods** are the actual callbacks - executed when the message
 *   is received. Inside the function body, `this` refers to the particular
 *   instance of the `Yako` class, *not* the message handler.
 * 
 * ```
 * ...
 * Destroy() {
 *     ToolTip("exiting script...")
 *     SetTimer(() => ExitApp(), -3000) ; exit in 3 seconds
 * }
 * ...
 * ```
 * 
 * 3. **Enjoy Inheritance-Like Behaviour**:
 * 
 * Message handler classes automatically inherit from the base classes. That
 * means that further base classes can override, extend, or ignore
 * functionality. Static methods register new callbacks, non-static methods
 * implement them - Yako lets you build your own kind of "interface" as you'd
 * expect from statically-typed languages like Java and C#.
 * 
 * ```
 * class Notepad extends ExitScriptWhenClosed {
 *     ; automatically inherits the `static Destroy()` and `Destroy()` methods
 *     class MessageHandler {
 *         static Size(Callback) {
 *             this.OnMessage(WM_SIZE := 0x0003, (this, wParam, lParam) {
 *                 ; wParam is not used. lParam contains x and y coords.
 *                 x := lParam & 0xFFFF
 *                 y := (lParam >>> 16) & 0xFFFF
 *                 return Callback(this, x, y)
 *             })
 *         }
 * 
 *         Size(x, y) {
 *             ToolTip("moving Notepad... " . x . " " . y)
 *         }
 *     }
 * }
 * ```
 * 
 * 
 * 4. **Create a Subclass Hook**:
 * 
 * To start intercepting messages, you need to **instantiate your class**
 * with a target window:
 * 
 * ```
 * NotepadHook := Notepad.FromWindow("ahk_exe notepad.exe")
 * ```
 * 
 * This hooks Notepad's main window and starts rerouting messages to
 * your AutoHotkey script.
 * 
 * ---
 * 
 * ### What Should my Callback Function Return?
 * 
 * Some Windows messages expect a meaningful return value. Yako gives you a few
 * ways to control how the message should be handled:
 * 
 * - **Return a Number**:
 * 
 * If your callback returns a number, it will be passed directly back as the
 * result of the message. The application responds to the message as you'd
 * normally expect.
 * 
 * ```
 * ...
 * return 0
 * ```
 * 
 * - **Default Behaviour**:
 * 
 * If your callback either:
 * - returns nothing
 * - returns an empty string (`""`), or
 * - returns either `Yako.DoDefault` or `this.DoDefault`,
 * 
 * then Yako will **fall through** and call the next window procedure (via
 * `DefSubclassProc()`)
 * 
 * ```
 * Size(Width, Height) {
 *     ToolTip("sizing..." . Width . " " . Height)
 *     return this.DoDefault
 * }
 * ```
 * 
 * ---
 * 
 * ### `.Free()`
 * 
 * Call `.Free()` to unhook the custom window procedure and **release all
 * allocated memory** related to the injection. Although Yako already
 * cleans up when your script exits, you can use this function to explicitly
 * unhook the window.
 * 
 * ```
 * Notepad.Free() ; stop listening to Notepad's window messages
 * ```
 * 
 * ---
 * 
 * ### `.ReadObject(StructClass, Ptr)`
 * 
 * Use `.ReadObject()` to **safely read a struct from the remote process**.
 * Directly deferencing memory from another process will trigger an access
 * violation - this method wraps the required `ReadProcessMemory` logic
 * and reads data into your given `StructClass` type.
 * 
 * ```
 * ...
 * static Sizing(Callback) {
 *     this.OnMessage(WM_SIZING := 0x0214, (this, wParam, lParam) {
 *         WindowEdge := wParam
 *         Bounds := this.ReadObject(RECT, lParam)
 *         return Callback(this, Bounds, WindowEdge)
 *     })
 * }
 * ...
 * ```
 */
class Yako {
    /**
     * Struct that is sent from the external application to the AHK script.
     */
    class Message {
        Msg     : u32   ; message ID
        wParam  : uPtr  ; wParam of the message
        lParam  : uPtr  ; lParam of the message
        result  : uPtr  ; if handled, this member acts as return value
        handled : i32   ; whether to consume the event instead of delegating it
    }

    /**
     * Default map of message callbacks, which is the base type for all `Yako`
     * subtypes. Each class is set up with its own `Messages` map, a special
     * map that supports inheritance down the chain of `Yako` classes.
     * 
     * @returns  {Yako.ChainedMap}
     */
    Messages {
        get {
            static MapObj := Yako.ChainedMap()
            return MapObj
        }
    }

    /**
     * Default, empty message handler, which is the base type for all message
     * handlers of `Yako` subtypes.
     */
    class MessageHandler {

    }

    /**
     * Static init. In this method, we set up events defined by the
     * `MessageHandler` class.
     */
    static __New() {
        if (this == Yako) {
            return
        }

        ; define a `Messages` map for this class, which inherits from
        ; the base type's `Messages`
        Messages := this.Prototype.Messages.Subclass()
        this.Prototype.DefineProp("Messages", { Get: (Instance) => Messages })

        ; if the class defines its own message handler, make it inherit
        ; from the base class' message handler
        if (!HasNestedClass(this, "MessageHandler")) {
            return
        }
        ObjSetBase(this.MessageHandler, ObjGetBase(this).MessageHandler)

        ; non-static methods are seen as the callback function to use as
        ; argument for the same-named static method
        MessageHandler := this.MessageHandler
        Callbacks := MessageHandler.Prototype

        ; enuerate through all non-static methods of the class
        for PropertyName in Callbacks.OwnProps() {
            ; ignore special AHK properties
            if (PropertyName = "__Class" || PropertyName = "__Init") {
                continue
            }

            ; ensure that the associated register method exists
            CallbackDesc := Callbacks.GetOwnPropDesc(PropertyName)
            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }
            if (!HasProp(MessageHandler, PropertyName)) {
                throw UnsetError("undefined event",, "static " . PropertyName)
            }

            ; NOTE we've already established through `HasProp` that the
            ;      property exists somewhere
            while (!ObjHasOwnProp(MessageHandler, PropertyName)) {
                MessageHandler := ObjGetBase(MessageHandler)
            }
            HandlerDesc := MessageHandler.GetOwnPropDesc(PropertyName)
            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }

            ; register the new message callback
            Callback := CallbackDesc.Call
            RegisterFunc := HandlerDesc.Call
            RegisterFunc(this.Prototype, Callback)
        }

        /**
         * Determines whether a class directly owns a nested class with the
         * given name.
         */
        static HasNestedClass(Cls, Name) {
            if (!ObjHasOwnProp(Cls, Name)) {
                return false
            }
            Desc := Cls.GetOwnPropDesc(Name)
            switch {
                case ObjHasOwnProp(Desc, "Get"):
                    return ((Desc.Get)(Cls) is Class)
                case ObjHasOwnProp(Desc, "Value"):
                    return (Desc.Value is Class)
                default:
                    return false
            }
        }
    }

    /**
     * A special map structure supporting inheritance from other maps
     * similar to a linked list. This is used for the `Messages` property
     * generated for each `Yako` class, which inherits from base classes.
     */
    class ChainedMap extends Map {
        /**
         * Returns a new chained map with the given base map to inherit from.
         */
        __New(Next := Map()) {
            this.Default := false

            if (!(Next is Map)) {
                throw TypeError("Expected a Map",, Type(Next))
            }

            this.DefineProp("Next", {
                Get: (Instance) => Next
            })
        }

        /**
         * Special enumerator that inherits previously unused keys from the
         * chain of `Next` maps.
         */
        __Enum(ArgSize) {
            Methods := Map()
            MapObj := this

            Loop {
                ; lex, add support for `for Name, Callback in super` frfr.
                for Name, Callback in (Map.Prototype.__Enum)(MapObj) {
                    if (!Methods.Has(Name)) {
                        Methods[Name] := Callback
                    }
                }
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    break
                }
                MapObj := MapObj.Next
            }
            return Methods.__Enum(ArgSize)
        }

        /**
         * Returns a value from the chained map.
         */
        Get(Key, Default?) {
            return super.Get(Key, Default?) || this.Next.Get(Key, Default?)
        }

        /**
         * Getter that supports inheritance.
         */
        __Item[Key] {
            get {
                return super[Key] || this.Next[Key]
            }
        }

        /**
         * Returns a new `ChainedMap` that inherits from this chained map.
         */
        Subclass() {
            return Yako.ChainedMap(this)
        }
    }

    /**
     * Waits for the specified window to open.
     */
    static WinWait(&Output, TimeoutSeconds?, Args*) {
        static IntervalMS := 100

        if (IsSet(TimeoutSeconds)) {
            TimeoutSeconds := Max(0, TimeoutSeconds)
            Count := 1
            MaxCount := TimeoutSeconds / (IntervalMS / 1000)
        }

        QueryFunction() {
            if (IsSet(TimeoutSeconds) && (Count++ > MaxCount)) {
                SetTimer(QueryFunction, false)
                return
            }
            Hwnd := WinExist(Args*)
            if (Hwnd) {
                SetTimer(QueryFunction, false)
                Output := this(Hwnd)
            }
        }
        SetTimer(QueryFunction, IntervalMS)
    }

    /**
     * Returns a new instance from the given Control parameters.
     */
    static FromControl(Ctl, WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := ControlGetHwnd(Ctl, WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /**
     * Returns a new instance from the given WinTitle parameters.
     */
    static FromWindow(WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := WinGetId(WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /**
     * Returns a new instance from the given Hwnd.
     */
    static FromHwnd(Hwnd) {
        return this(Hwnd)
    }

    /**
     * Returns a new instance from the given Hwnd.
     */
    __New(TargetHwnd) {
        static PROCESS_VM_READ := 0x10

        ; map of all actively subclassed windows
        static Instances := Map()
        static OnExitCallback := OnExit((*) {
            for Instance, _ in Instances {
                Instance.__Delete()
            }
        })

        ; retrieve the Hwnd of the targeted window, and create a subclass
        Hwnd := (IsObject(TargetHwnd)) ? TargetHwnd.Hwnd : TargetHwnd
        if (!IsInteger(Hwnd)) {
            throw TypeError("Expected an Object or Integer",, Type(Hwnd))
        }
        this.DefineProp("Hwnd", { Get: (Instance) => Hwnd })

        ; find the process ID of the targeted window
        PID := 0
        DllCall("GetWindowThreadProcessId", "Ptr", Hwnd, "UInt*", &PID)
        ProcessHandle := DllCall("OpenProcess", "UInt", PROCESS_VM_READ,
                "Int", false, "UInt", PID)
        
        this.DefineProp("ProcessHandle", { Get: (Instance) => ProcessHandle })

        ; define function called by external window
        OnMessageCallback := (wParam, lParam, Msg, Hwnd) {
            YakoMsg := StructFromPtr(Yako.Message, lParam)

            Callback := this.Messages.Get(YakoMsg.Msg, false)
            if (!Callback) {
                return
            }
            Result := Callback(this, YakoMsg.wParam, YakoMsg.lParam)
            if (Result == "" || Result == Yako.DoDefault) {
                return
            }
            YakoMsg.Result := Result
            YakoMsg.Handled := true
        }

        Instances.Set(this, true)

        this.DefineProp("__Delete", { Call: (Instance) {
            DllCall("CloseHandle", "Ptr", Instance.ProcessHandle)
            try SendMessage(0x4CCC, 0x4CCC, 0x4CCC, Instance)
            OnMessage(0x3CCC, OnMessageCallback, false)
            Instances.Delete(Instance)
        } })

        ; register the callback function and then finally, subclass the window
        OnMessage(0x3CCC, OnMessageCallback)
        Inject(Hwnd)

        /**
         * Overrides the subclass procedure of a window by the given Hwnd.
         */
        static Inject(Hwnd) {
            static Injector   := A_LineFile . "\..\injector.dll\inject"
            static WindowProc := A_LineFile . "\..\windowProc.dll"

            Result := DllCall(Injector, "Ptr", Hwnd,
                                        "Ptr", A_ScriptHwnd,
                                        "Str", WindowProc)
            switch (Result) {
                case 1: Msg := "Unable to open process of AutoHotkey script."
                case 2: Msg := "Unable to allocate virtual memory."
                case 3: Msg := "Unable to write into process"
                case 4: Msg := "Unable to create remote thread"
                case 5: Msg := "Unable to load 'windowProc.dll'"
                case 6: Msg := "Unable to resolve 'windowProc/init'"
            }
            if (Result) {
                throw OSError(Msg)
            }
        }
    }

    /**
     * Used as return value to pass the message to the next window procedure
     * instead of consuming it.
     */
    DoDefault => Yako.DoDefault

    /**
     * An object that signals that the message should be deferred to the next
     * window procedure instead of being consumed.
     */
    static DoDefault {
        get {
            static _ := Object()
            return _
        }
    }

    /**
     * Removes the overridden window procedure and frees associated memory.
     */
    Free() => this.__Delete()

    /**
     * Reads an object from the window.
     */
    ReadObject(StructClass, Ptr) {
        Output := StructClass()
        OutSize := ObjGetDataSize(Output)
        OutPtr := ObjGetDataPtr(Output)

        DllCall("ReadProcessMemory", "Ptr", this.ProcessHandle, "Ptr", Ptr,
                "Ptr", OutPtr, "UPtr", OutSize, "Ptr", 0)
        return Output
    }

    /**
     * Registers a function to be called when the window triggers the given
     * message number.
     * 
     * @param   {Integer}  MsgNumber  message number to monitor
     * @param   {Func}     Callback   the function to be called
     */
    OnMessage(MsgNumber, Callback) {
        if (!IsInteger(MsgNumber)) {
            throw TypeError("Expected an Integer",, Type(MsgNumber))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object",, Type(Callback))
        }
        this.Messages.Set(MsgNumber, Callback)
    }

    #Include "%A_LineFile%/../Yako.Gui.ahk"
}

; NotepadObj := Notepad.FromWindow("ahk_exe notepad.exe")

esc:: {
    ExitApp()
}

class Tenko extends AquaHotkey {
    static __New() {
        if (true) {
            return
        }

        super.__New()
        if (!IsSet(Yako) || !(Yako is Class)) {
            return
        }

        Cls := Class()
        Cls.Prototype := Object()
        Cls.Prototype.__Class := "<Internal>"

        Clone := this.Clone()
        Clone.DeleteProp("__New")
        ObjSetBase(Clone, Object) ; remove inheritance from `AquaHotkey_Ignore`

        Cls.DefineProp("Yako", {
            Get: (Instance) => Clone,
            Call: (Instance, Args*) => Clone(Instance, Args*)
        })

        ObjSetBase(Cls, AquaHotkey)
        Cls.__New()
    }
}

class RECT {
    Left   : u32
    Top    : u32
    Right  : u32
    Bottom : u32
}

class ModifierKeys {
    Value : u16

    __New(Value) {
        this.Value := Value
    }

    LButton  => 0x0001
    RButton  => 0x0002
    Shift    => 0x0004
    Control  => 0x0008
    MButton  => 0x0010
    XButton1 => 0x0020
    XButton2 => 0x0040

    static LButton  => !!(this.Value & 0x0001)
    static RButton  => !!(this.Value & 0x0002)
    static Shift    => !!(this.Value & 0x0004)
    static Control  => !!(this.Value & 0x0008)
    static MButton  => !!(this.Value & 0x0010)
    static XButton1 => !!(this.Value & 0x0020)
    static XButton2 => !!(this.Value & 0x0040)
}

class Notepad extends Yako.Gui {
    class MessageHandler {
        ;Destroy() {
        ;    ToolTip("quitting...")
        ;    SetTimer(() => ExitApp(), -3000)
        ;}

        EnterSizeMove() {
            ToolTip("Entering size/move loop...")
        }

        ;Close() {
        ;    Result := MsgBox("Are you sure you want to quit?", "Notepad", 0x0001)
        ;    return (Result = "OK") ? this.DoDefault : 0
        ;}

        QueryOpen() {
            return Random(true, false)
        }

        ;Quit(ExitCode) {
        ;    MsgBox(ExitCode)
        ;}

        ;ActivateApp(IsActivated, ThreadId) {
        ;    ToolTip(IsActivated " " ThreadId)
        ;    return 0
        ;}

        SetCursor(HitTest, MsgNumber, Hwnd) {
            if (HitTest == 2) {
                ToolTip("hovering over caption...")
            } else {
                ToolTip("not hovering over caption.")
            }
        }
    }
}

ToolTip("waiting for Notepad to open...")
SetTimer(() => ToolTip(), -2000)
Notepad.WinWait(&Hook, unset, "ahk_exe notepad.exe")
