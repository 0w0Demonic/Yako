#Requires AutoHotkey >=v2.1-alpha.9 ; requires structs and `StructFromPtr()`
/**
 * ```
 *  ,-.    ,_~*, /
 *     \ ,´_, ´ /        _,
 *      l (_|, /__   .*´  l\  _@&^""-._o
 *   <_/     `/\  (o)      `*$m^
 * ```
 * https://www.github.com/0w0Demonic/Yako
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
     * The `Messages` property contains all callbacks that are being handled
     * by the script. Each class is set up with its own `Messages` map, which
     * is a special "chained map" type that supports inheritance down the chain
     * of `Yako` classes.
     * 
     * `Yako.Message` is an empty map that act as root for all other subtypes.
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
     * Default `MessageHandler` class. It is the base type for each
     * subsequent message handler, up the inheritance chain of `Yako` classes.
     */
    class MessageHandler {
        ; (empty class)
    }

    /**
     * Static init. As soon as the class is loaded, events defined in the
     * `MessageHandler` class are properly being set up into a set of
     * callbacks, backed up by the `Messages` map.
     * 
     * Static methods, which are used to register new callbacks, are being
     * directly called in this method, passing the associated non-static
     * version of the method of the same name.
     * 
     * In other words, this is where the magic behind e.g. `static Destroy()`
     * and `Destroy()` is happening.
     */
    static __New() {
        ; We only need to do this for subclasses of `Yako`.
        if (this == Yako) {
            return
        }

        ; Create and define a new `Messages` map for this class' prototype,
        ; which inherits from the base type's `Messages`.
        Messages := this.Prototype.Messages.Subclass()
        this.Prototype.DefineProp("Messages", {
            Get: (_) => Messages
        })

        ; If the current class defines its own `MessageHandler` class, we make
        ; it inherit from the base class' `MessageHandler`.
        if (!HasNestedClass(this, "MessageHandler")) {
            return
        }
        ObjSetBase(this.MessageHandler, ObjGetBase(this).MessageHandler)

        ; Retrieve the message handler class and its prototype.
        MessageHandler := this.MessageHandler
        Callbacks := MessageHandler.Prototype

        ; Iterate through all non-static methods of the message handler.
        for PropertyName in Callbacks.OwnProps() {
            ; Ignore special AHK properties.
            ; TODO also ignore `__New()`?
            if (PropertyName = "__Class" || PropertyName = "__Init") {
                continue
            }

            ; Only methods are allowed.
            CallbackDesc := Callbacks.GetOwnPropDesc(PropertyName)
            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }

            ; Ensure that a static "registration" method exists somewhere.
            if (!HasProp(MessageHandler, PropertyName)) {
                throw UnsetError("undefined event",, "static " . PropertyName)
            }

            ; Find the prop desc of the static registration method, by going
            ; down the chain of base classes and checking `ObjHasOwnProp()`.
            ; 
            ; Note that we already know through `HasProp()` that the property
            ; exists somewhere down the inheritance chain.
            Cls := MessageHandler
            while (!ObjHasOwnProp(Cls, PropertyName)) {
                Cls := ObjGetBase(Cls)
            }

            ; Only methods are allowed.
            HandlerDesc := Cls.GetOwnPropDesc(PropertyName)
            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }

            ; Register the new callback by calling the registration method,
            ; passing the actual implementation as parameter.
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
     * A special map structure that supports inheritance down a "chain of maps",
     * very similar to a linked list. This type is used for the `Messages`
     * property generated for each `Yako` class.
     */
    class ChainedMap extends Map {
        /**
         * Returns a new chained map with the given base map to inherit from.
         */
        __New(Next := CreateMap()) {
            static CreateMap() {
                M := Map()
                M.Default := false
                M.CaseSense := false
                return M
            }

            this.Default := false
            this.CaseSense := false

            if (!(Next is Map)) {
                throw TypeError("Expected a Map",, Type(Next))
            }

            ; define next map to be searched whenever no value could be found.
            this.DefineProp("Next", {
                Get: (Instance) => Next
            })
        }

        /**
         * Special enumerator that inherits previously unused keys from the
         * chain of `Next` maps.
         */
        __Enum(ArgSize) {
            ; Create a case-insensitive map that keeps track of elements.
            Methods := Map()
            Methods.CaseSense := false

            ; Loop through the chain of maps, starting with `this`.
            MapObj := this
            Loop {
                ; y'know what would be cool? `for Name, Callback in super`.
                ; But I guess it's something you won't ever need elsewhere.
                for Name, Callback in (Map.Prototype.__Enum)(MapObj) {
                    ; Only add callbacks which don't exist yet. This mimics the
                    ; way how a previous map "overrides" the previous callback.
                    if (!Methods.Has(Name)) {
                        Methods[Name] := Callback
                    }
                }
                ; `Next` refers to the next map to iterate through.
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    break
                }
                MapObj := MapObj.Next
            }
            ; Finally, return an enumerator of the map.
            return Methods.__Enum(ArgSize)
        }

        /** Returns a value from the chained map. */
        Get(Key, Default?) {
            return super.Get(Key, Default?) || this.Next.Get(Key, Default?)
        }

        /** Returns a value from the chained map. */
        __Item[Key] {
            get {
                return super[Key] || this.Next[Key]
            }
        }

        /** Returns a new `ChainedMap` that inherits from this chained map. */
        Subclass() {
            return Yako.ChainedMap(this)
        }
    }

    /** Waits for the specified window to open. */
    static WinWait(&Output, TimeoutSeconds?, WinTitleParams*) {
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
            Hwnd := WinExist(WinTitleParams*)
            if (Hwnd) {
                SetTimer(QueryFunction, false)
                Output := this(Hwnd)
            }
        }
        SetTimer(QueryFunction, IntervalMS)
    }

    /** Returns a new instance from the given Control parameters. */
    static FromControl(Ctl, WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := ControlGetHwnd(Ctl, WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /** Returns a new instance from the given WinTitle parameters. */
    static FromWindow(WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := WinGetId(WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /** Returns a new instance from the given Hwnd. */
    static FromHwnd(Hwnd) {
        return this(Hwnd)
    }

    /** Returns a new instance from the given Hwnd. */
    __New(TargetHwnd) {
        static PROCESS_VM_READ      := 0x10
        static WM_YAKO_MESSAGE      := 0x3CCC
        static WM_YAKO_FREE_MESSAGE := 0x4CCC

        ; Map of all actively subclassed windows
        static Instances := Map()
        static OnExitCallback := OnExit((*) {
            for Instance, _ in Instances {
                Instance.__Delete()
            }
        })

        ; Retrieve the Hwnd of the targeted window, and create a subclass
        Hwnd := (IsObject(TargetHwnd)) ? TargetHwnd.Hwnd : TargetHwnd
        if (!IsInteger(Hwnd)) {
            throw TypeError("Expected an Object or Integer",, Type(Hwnd))
        }
        this.DefineProp("Hwnd", { Get: (_) => Hwnd })

        ; Find the process ID of the targeted window
        PID := 0
        DllCall("GetWindowThreadProcessId", "Ptr", Hwnd, "UInt*", &PID)
        ProcessHandle := DllCall("OpenProcess", "UInt", PROCESS_VM_READ,
                "Int", false, "UInt", PID)
        
        this.DefineProp("ProcessHandle", { Get: (_) => ProcessHandle })

        ; Define function called by external window
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

        ; Add this object to the pool, and decrement reference count to
        ; compensate.
        Instances.Set(this, true)
        ObjRelease(ObjPtr(this))

        ; Specify method to be called on deletion.
        this.DefineProp("__Delete", { Call: (Instance) {
            DllCall("CloseHandle", "Ptr", Instance.ProcessHandle)
            try SendMessage(WM_YAKO_FREE_MESSAGE,
                            WM_YAKO_FREE_MESSAGE,
                            WM_YAKO_FREE_MESSAGE,
                            Instance)
            OnMessage(WM_YAKO_MESSAGE, OnMessageCallback, false)
            Instances.Delete(Instance)
        } })

        ; Register the callback function and then finally, subclass the window
        OnMessage(WM_YAKO_MESSAGE, OnMessageCallback)
        Inject(Hwnd)

        /** Overrides the subclass procedure of a window by the given Hwnd. */
        static Inject(Hwnd) {
            static Injector   := A_LineFile . "\..\..\bin\injector.dll\inject"
            static WindowProc := A_LineFile . "\..\..\bin\windowProc.dll"

            Result := DllCall(Injector,
                    "Ptr", Hwnd,         ; HWND to inject
                    "Ptr", A_ScriptHwnd, ; HWND of this script
                    "Str", WindowProc)   ; File path to the injected DLL
            
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
     * 
     * @param   {Class}    StructClass  the struct type to read
     * @param   {Integer}  Ptr          the pointer (in foreign memory) to read
     * @return  {Object}
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
     * @return  {this}
     */
    OnMessage(MsgNumber, Callback) {
        if (!IsInteger(MsgNumber)) {
            throw TypeError("Expected an Integer",, Type(MsgNumber))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object",, Type(Callback))
        }
        this.Messages.Set(MsgNumber, Callback)
        return this
    }

    #Include "%A_LineFile%/../Yako.Gui.ahk"
}

; NotepadObj := Notepad.FromWindow("ahk_exe notepad.exe")

esc:: {
    ExitApp()
}

/*
; some experiments with a lib that extends `Gui` types, ignore this
#Include <AquaHotkeyX>

class Tenko extends AquaHotkey {
    static __New() {
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
*/

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
        Destroy() {
            ToolTip("quitting...")
            SetTimer(() => ExitApp(), -3000)
        }

        EnterSizeMove() {
            ToolTip("Entering size/move loop...")
        }

        Close() {
            Result := MsgBox("Are you sure you want to quit?", "Notepad", 0x0001)
            return (Result = "OK") ? this.DoDefault : 0
        }

        QueryOpen() {
            return Random(true, false)
        }

        Quit(ExitCode) {
            MsgBox(ExitCode)
        }

        ActivateApp(IsActivated, ThreadId) {
            Status := (IsActivated) ? "Activated" : "Deactivated"
            ToolTip(Status . " (Thread ID: " . ThreadId . ")")
            return 0
        }

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
