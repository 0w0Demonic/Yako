/**
 * ```
 *   _ 
 *  ´ `     ,_~*- /
 *     \  ,´_,   /        _,
 *      l´ (_|, /__   .*´  l\  _@&^""-._
 *     /      `/\  (o)      `*$m^               
 * <__´          \
 * ```
 * https://www.github.com/0w0Demonic/Yako
 * 
 * Yako is an AutoHotkey library that uses DLL injection to intercept window
 * messages in external applications, allowing you to modify and reprogram
 * their behavior.
 */
class Yako {
    /** File path to `injector.dll` */
    static Injector => A_LineFile . "\..\injector.dll"

    /** File path to `windowProc.dll` */
    static WindowProc => A_LineFile . "\..\windowProc.dll"

    /** Message number used for callbacks to the AHK script */
    static MsgNumber => 0x3CCC

    /** Creates a new window hook from the given GUI control */
    static FromControl(Ctl, WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := ControlGetHwnd(Ctl, WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /** Creates a new window hook from the given application */
    static FromWindow(WTtl?, WTxt?, ETtl?, ETxt?) {
        Hwnd := WinGetId(WTtl?, WTxt?, ETtl?, ETxt?)
        return this(Hwnd)
    }

    /** Creates a new window hook from the given HWND */
    __New(TargetHwnd) {
        Hwnd := (IsObject(TargetHwnd)) ? TargetHwnd.Hwnd
                                       : TargetHwnd
        if (!IsInteger(Hwnd)) {
            throw TypeError("Expected an Object or Integer",, Type(Hwnd))
        }

        Result := DllCall(Yako.Injector . "\inject", "Ptr", Hwnd, "Ptr",
                          A_ScriptHwnd, "Str", Yako.WindowProc)
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

        Callback := ObjBindMethod(this, "MsgHandler")

        PID := 0
        DllCall("GetWindowThreadProcessId", "Ptr", Hwnd, "UInt*", &PID)
        hProcess := DllCall("OpenProcess", "UInt", 0x10, "Int", false,
                "UInt", PID)
        
        Define("Process", hProcess)
        Define("Messages", CreateMap())
        Define("Commands", CreateMap())
        Define("Notifs", CreateMap())

        OnMessage(Yako.MsgNumber, Callback)

        static CreateMap() {
            M := Map()
            M.Default := false
            return M
        }

        Define(PropName, Value) {
            this.DefineProp(PropName, { Get: (Instance) => Value })
        }
    }

    OnMessage(MsgNumber, Callback) {
        if (!IsInteger(MsgNumber)) {
            throw TypeError("Expected an Integer",, Type(MsgNumber))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object", Type(Callback))
        }
        this.Messages[MsgNumber] := Callback
    }

    OnNotify(NotifyCode, Callback) {
        if (!IsInteger(NotifyCode)) {
            throw TypeError("Expected an Integer",, Type(NotifyCode))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object", Type(Callback))
        }
        this.Notifs[NotifyCode] := Callback
    }

    OnCommand(NotifyCode, Callback) {
        if (!IsInteger(NotifyCode)) {
            throw TypeError("Expected an Integer",, Type(NotifyCode))
        }
        if (!HasMethod(Callback)) {
            throw TypeError("Expected a Function object", Type(Callback))
        }
        this.Commands[NotifyCode] := Callback
    }

    MsgHandler(wParam, lParam, Msg, Hwnd) {
        TanukiMsg := StructFromPtr(Yako.Message, lParam)

        Callback := this.Messages[TanukiMsg.Msg]
        if (!Callback) {
            return
        }

        Result := Callback(this, TanukiMsg.wParam, TanukiMsg.lParam)
        if (Result == "" || Result == Yako.DoDefault) {
            return
        }
        TanukiMsg.Result := Result
        TanukiMsg.Handled := true
    }

    DoDefault => Yako.DoDefault

    static DoDefault {
        get {
            static _ := Object()
            return _
        }
    }

    __Delete() {
        DllCall("CloseHandle", "Ptr", this.Process)
        ; TODO need to free the old subclass procedure when AHK quits
        ;      probably create `__declspec(dllexport) void free()` function
    }

    ReadObject(StructClass, Ptr) {
        Output := StructClass()
        OutSize := ObjGetDataSize(Output)
        OutPtr := ObjGetDataPtr(Output)
        DllCall("ReadProcessMemory", "Ptr", this.Process, "Ptr", Ptr,
                "Ptr", OutPtr, "UPtr", OutSize, "Ptr", 0)
        return Output
    }

    class Message {
        Msg     : u32
        wParam  : uPtr
        lParam  : uPtr
        result  : uPtr
        handled : i32
    }
}


class RECT {
    Left   : u32
    Top    : u32
    Right  : u32
    Bottom : u32
}

/**
 * ```
 * ```
 */
class YakoGui extends Yako {
    ; TODO just loop through these and "inject" a `GetMethod()` check
    ;      to save space?
    ;      do the same with "return this"?

    /**
     * Sent when the window is being destroyed.
     * @example
     * 
     * MyGui.Destroy((this) {
     *     MsgBox("quitting...")
     *     SetTimer(() => ExitApp(), -500)
     *     return 0
     * })
     * 
     * @param   {Func}  Callback  the function to be called
     * @return  {this}
     */
    Destroy(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_DESTROY := 0x0002, (GuiObj, wParam, lParam) {
            return Callback(GuiObj)
        })
        return this
    }

    /**
     * Sent when the window is being moved.
     * @example
     * 
     * MyGui.Move((this, x, y) {
     *     ToolTip("position: " . x . " " . y)
     *     return this.DoDefault
     * })
     * 
     * @param   {Func}  Callback  the function to be called
     * @return  {this}
     */
    Move(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_MOVE := 0x0003, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, lParam & 0xFFFF, (lParam >>> 16) & 0xFFFF)
        })
        return this
    }

    /**
     * Sent when the size of the window is being changed.
     * @example
     * 
     * MyGui.Size((this, Width, Height) {
     *     ToolTip("size: " . Width . " " . Height)
     *     return this.DoDefault
     * })
     * 
     * @param   {Func}  Callback  the function to be called
     * @return  {this}
     */
    Size(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SIZE := 0x0005, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
        })
        return this
    }

    ; TODO split into de/activate?
    /**
     * Sent when the window receives keyboard focus.
     * @example
     * 
     * MyGui.Activate((this, OtherHwnd, Clicked) {
     *     ToolTip((Clicked) ? "activated (click)." : "activated.")
     *     return this.DoDefault
     * })
     * 
     * @param   {Func}  Callback  the function to be called
     * @return  {this}
     */
    Activate(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_ACTIVATE := 0x0006, (GuiObj, wParam, lParam) {
            if (!wParam) {
                return GuiObj.DoDefault
            }
            return Callback(GuiObj, lParam, wParam == 2)
        })
        return this
    }

    ; TODO split this?
    /**
     * Sent when the window loses keyboard focus.
     * @example
     * 
     * MyGui.Deactivate((this, OtherHwnd) {
     *     ToolTip("deactivated. new window: " . OtherHwnd)
     * })
     * 
     * @param   {Func}  Callback  the function to be called
     * @return  {this}
     */
    Deactivate(Callback) {

    }

    Focus(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SETFOCUS := 0x0007, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
        return this
    }

    FocusLost(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_KILLFOCUS := 0x0008, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
        return this
    }

    Enable(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_ENABLE := 0x000A, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
        return this
    }

    SetRedraw(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SETREDRAW := 0x000B, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
        return this
    }

    SetText(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SETTEXT := 0x000C, (GuiObj, wParam, lParam) {
            
        })
        return this
    }

    ; ...

    Sizing(Callback) {
        this.OnMessage(WM_SIZING := 0x0214, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam, this.ReadObject(RECT, lParam))
        })
        return this
    }
}

Notepad := YakoGui.FromWindow("ahk_exe notepad.exe")
Notepad.Activate((this, OtherHwnd, Clicked) {
    ToolTip(Clicked)
    return this.DoDefault
})

^space:: {

}
