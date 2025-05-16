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
 * Yako is an AutoHotkey library that uses DLL injection to intercept window
 * messages in external applications, allowing you to modify and reprogram
 * their behavior.
 */
class Yako {
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
     * 
     * ### How do I use this?
     * 
     * Inside the message handler class, static methods define how new messages
     * should be registered. They should usually call `.OnMessage(...)`.
     * 
     * ```
     * ...
     * static Destroy(Callback) {
     *     GetMethod(Callback)
     *     this.OnMessage(WM_DESTROY := 0x0002, (this, wParam, lParam) {
     *         return Callback(this)
     *     })
     * }
     * ...
     * ```
     * 
     * Non-static methods define the implementations which should be used by
     * that particular class:
     * 
     * ```
     * ...
     * Destroy() {
     *     ToolTip("quitting...")
     *     SetTimer(() => ExitApp(), -1000)
     * }
     * ...
     * ```
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
        this.DefineProp("Messages", { Get: (Instance) => Messages })

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
     * similar to a linked list.
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
     * Defines register functions associated for GUIs
     */
    class Gui extends Yako {
        class MessageHandler {
            static Destroy(Callback) {
                GetMethod(Callback)
                this.OnMessage(WM_DESTROY := 0x0002, (GuiObj, wParam, lParam) {
                    Callback(GuiObj)
                    return GuiObj.DoDefault
                })
            }

            static Move(Callback) {
                GetMethod(Callback)
                this.OnMessage(WM_MOVE := 0x0003, (GuiObj, wParam, lParam) {
                    x := lParam & 0xFFFF
                    y := (lParam >>> 16) & 0xFFFF
                    return Callback(GuiObj, x, y)
                })
            }
        }
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
        this.DefineProp("PID", { Get: (Instance) => PID })

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
            DllCall("CloseHandle", "Ptr", Instance.PID)
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

        DllCall("ReadProcessMemory", "Ptr", this.PID, "Ptr", Ptr,
                "Ptr", OutPtr, "UPtr", OutSize, "Ptr", 0)
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
}

class Notepad extends Yako.Gui {
    class MessageHandler {
        Move(x, y) {
            static WasMoved := false
            if (!WasMoved) {
                WasMoved := true
                ToolTip("quitting...")
                SetTimer(() => this.Free(), -2000)
            }
        }

        Destroy() {
            MsgBox("destroyed!")
        }
    }

    DoSomething() {
        MsgBox("I am doing something!")
    }
}

; NotepadObj := Notepad.FromWindow("ahk_exe notepad.exe")

esc:: {
    ExitApp()
}

class Tenko extends AquaHotkey {
    static __New() {
        if (this != Tenko || !IsSet(Yako) || !(Yako is Class)) {
            return
        }
        Cls := Class()
        Cls.Prototype := Object()
        Cls.Prototype.__Class := "<Internal>"

        Clone := this.Clone()

        this.DefineProp("Yako", {
            Get: (Instance) => Clone,
            Call: (Instance, Args*) => Clone(Instance, Args*)
        })

        (AquaHotkey.__New)(Cls)
    }

    class Gui {
        static SpecialProperty() {

        }
    }
}
