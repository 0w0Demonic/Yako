#Requires AutoHotkey >=v2.1-alpha.9
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
    Messages {
        get {
            static MapObj := Yako.LinkedMap()
            return MapObj
        }
    }

    class MessageHandler {

    }

    static __New() {
        if (this == Yako) {
            return
        }

        Messages := this.Prototype.Messages.Subclass()
        this.DefineProp("Messages", { Get: (Instance) => Messages })

        if (!HasNestedClass(this, "MessageHandler")) {
            return
        }

        ObjSetBase(this.MessageHandler, ObjGetBase(this).MessageHandler)

        MessageHandler := this.MessageHandler
        Callbacks := MessageHandler.Prototype

        for PropertyName in Callbacks.OwnProps() {
            if (PropertyName = "__Class") {
                continue
            }

            ; TODO better error messages
            CallbackDesc := Callbacks.GetOwnPropDesc(PropertyName)
            if (!HasProp(MessageHandler, PropertyName)) {
                throw UnsetError("undefined event",, "static " . PropertyName)
            }
            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }

            ; TODO loop through base chain instead of %%-ing?
            while (!ObjHasOwnProp(MessageHandler, PropertyName)) {
                MessageHandler := ObjGetBase(MessageHandler)
            }

            HandlerDesc := MessageHandler.GetOwnPropDesc(PropertyName)

            if (!ObjHasOwnProp(CallbackDesc, "Call")) {
                throw ValueError("only methods allowed")
            }

            Callback := CallbackDesc.Call
            Handler := HandlerDesc.Call
            Handler(this.Prototype, Callback)
        }

        /**
         * 
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
    class LinkedMap extends Map {
        /**
         * Returns a new MessageHandler map with the given base map to
         * inherit from.
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
         * Returns a value from the MessageHandler map.
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
         * Returns a new MessageHandler with `this` as its base.
         */
        Subclass() {
            return Yako.LinkedMap(this)
        }
    }

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

    static FromControl(Ctl, WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := ControlGetHwnd(Ctl, WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    static FromWindow(WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := WinGetId(WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    static FromHwnd(Hwnd) {
        return this(Hwnd)
    }

    __New(TargetHwnd) {
        static PROCESS_VM_READ := 0x10
        static Instances := Map()
        static OnExitCallback := OnExit((*) {
            for Instance in Instances {
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

        this.DefineProp("__Delete", { Call: () {
            DllCall("CloseHandle", "Ptr", PID)
            SendMessage(0x4CCC, 0x4CCC, 0x4CCC, this)
            OnMessage(0x3CCC, OnMessageCallback, false)
        } })

        ; register the callback function and then finally, subclass the window
        OnMessage(0x3CCC, OnMessageCallback)
        Inject(Hwnd)

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

    DoDefault => Yako.DoDefault

    static DoDefault {
        get {
            static _ := Object()
            return _
        }
    }

    Free() => this.__Delete()

    ReadObject(StructClass, Ptr) {
        Output := StructClass()
        OutSize := ObjGetDataSize(Output)
        OutPtr := ObjGetDataPtr(Output)

        DllCall("ReadProcessMemory", "Ptr", this.PID, "Ptr", Ptr,
                "Ptr", OutPtr, "UPtr", OutSize, "Ptr", 0)
    }

    OnMessage(MsgNumber, Callback) {
        if (!IsInteger(MsgNumber)) {
            throw TypeError("Expected an Integer",, Type(MsgNumber))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object",, Type(Callback))
        }
        this.Messages.Set(MsgNumber, Callback)
    }

    class Message {
        Msg     : u32
        wParam  : uPtr
        lParam  : uPtr
        result  : uPtr
        handled : i32
    }
}

class Notepad extends Yako.Gui {
    class MessageHandler {
        Destroy() {
            SetTimer(() => ExitApp(), -2000)
        }

        Move(x, y) {
            ToolTip(x " " y)
            return this.DoDefault
        }
    }

    DoSomething() {
        MsgBox("I am doing something!")
    }
}

NotepadObj := Notepad.FromWindow("ahk_exe notepad.exe")

space:: {

}


