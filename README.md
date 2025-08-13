
# Yako - Whispering to Windows From Within

Yako is an AutoHotkey v2 library that lets you overwrite window procedures
of external applications. This is done via DLL injection, a well-known
hacking technique that involves injecting code into foreign processes.

After "connecting" to a window or control (see below), all incoming window
messages are rerouted into the AutoHotkey script, giving you
complete control over how they're handled.

---

## How to Use

```ahk
class ExitScriptWhenClosed extends Yako {
    class MessageHandler {
        static Destroy(Callback) {
            this.OnMessage(WM_NCDESTROY := 0x0082, (Obj, wParam, lParam) {
                return Callback(Obj)
            })
        }
        Destroy() {
            ToolTip("exiting script...")
            SetTimer(() => ExitApp(), -3000)
        }
    }
}
```

## What This Example Does

This examples defines a class `ExitScriptWhenClosed`, which extends the
`Yako` class. It listens for the `WM_NCDESTROY` message, which Windows sends
when a window is just about to be destroyed. When the message is received,
the script exits.

In other words: the hooked window closes, the script closes.

---

## How it Works

**Subclass `Yako`**:

You make a new class that inherits from `Yako`.
Inside it, create a nested class `MessageHandler`. This is where you decide
which messages to listen for, and how to react to them.

```ahk
class ExitScriptWhenClosed extends Yako {
    class MessageHandler {
        
    }
}
```

**Static "Registration" Methods**:

Static methods determine how to register new callbacks.

```ahk
static Destroy(Callback) { ... }
```

They accept a single parameter which is the callback function that should
be registered. Use `this.OnMessage(MsgNumber, Callback)` to register the new
callback.

```ahk
this.OnMessage(WM_NCDESTROY := 0x0082, Callback)
```

By default, a callback function accepts the relevant object (`this`), as
well as the wParam and lParam of the incoming message (see below).

**Non-static "Implementation" Methods**:

The real handling logic lives in a non-static method with the same name
(in this case `Destroy()`). When the message is received, Yako automatically
calls this method in response.

```ahk
Destroy(wParam, lParam) {
    ToolTip("Closing...")
    SetTimer(() => ExitApp(), -3000) ; exits in 3 seconds
}
```

In the `WM_NCDESTROY` message, the wParam and lParam are not being used.
Sometimes, you might not care about the raw `wParam` and `lParam` values at
all. If your handler doesn't need them, you can wrap the callback so
they're ignore entirely.

In other cases, you can create more relevant objects based on wParam and
lParam to make message handling a lot easier. For example, you can turn
an lParam value into x- and y-coordinates, which is done for `WM_MOVE` and
many other messages.

```ahk
this.OnMessage(WM_NCDESTROY := 0x0082, (this, wParam, lParam) {
    return Callback(this) ; leave out wParam and lParam
})

Destroy() {
    ; (same as before)
}
```

**Enjoy Inheritance-Like Behavior**:

Message handler classes automatically inherit from the base classes.

```
Notepad                 |  Notepad.MessageHandler
`- ExitScriptWhenClosed |  `- ExitScriptWhenClosed.MessageHandler
   `- Yako              |     `- Yako.MessageHandler
```

That means that further base classes can override, extend, or ignore
functionality. Static methods register new callbacks, non-static methods
implement them - Yako lets you build your own kind of "interfaces" that
determine how messages should be handled and how to implement them.

```ahk
; automatically inherits the `static Destroy()` and `Destroy()` methods,
; because the `Notepad` class is based on the previous
; `ExitScriptWhenClosed`.
class Notepad extends ExitScriptWhenClosed
{
    class MessageHandler {
        static Size(Callback) {
            this.OnMessage(WM_SIZE := 0x0003, (this, wParam, lParam) {
                ; wParam is not used. lParam contains x and y coords.
                x := lParam & 0xFFFF
                y := (lParam >>> 16) & 0xFFFF
                return Callback(this, x, y)
            })
        }

        Size(x, y) {
            ToolTip("moving Notepad... " . x . " " . y)
        }
    }
}
```

**Connect to a Window or Control**:

To start intercepting messages, you need to **instantiate your class**
with a target window:

```ahk
NotepadHook := Notepad.FromWindow("ahk_exe notepad.exe")
```

Available methods:

- `static WinWait(&Output, TimeoutSeconds?, WinTitleParams*)`
- `static FromControl(Ctl, WTtl?, WTxt?, ETtl?, ETxt?)`
- `static FromWindow(WTtl?, WTxt?, ETtl?, ETxt?)`
- `static FromHwnd(Hwnd)`
- `__New(TargetHwnd)`

This hooks Notepad's main window and starts rerouting messages to
your AutoHotkey script.

---

### What Should my Callback Function Return?

Some Windows messages expect a meaningful return value. Yako gives you a few
ways to control how the message should be handled:

- **Return a Number**:

If your callback returns a number, it will be passed directly back as the
result of the message. The application responds to the message as you'd
normally expect.

```ahk
...
return 0
```

- **Default Behavior**:

If your callback either:

- returns nothing
- returns an empty string (`""`), or
- returns `Yako.DoDefault`/`this.DoDefault`,

then Yako will **fall through** and call the next window procedure (in other
words, via `DefSubclassProc()`). Most of the time, this is the recommended
way to handle return values because otherwise, the next window procedure
will not be called. This also means, however, that you can prevent certain
window messages from being processed. In theory, you could intercept
`WM_MOVING` and `WM_SIZING` to prevent the user from resizing/moving the
window.

```ahk
Size(Width, Height) {
    ToolTip("sizing..." . Width . " " . Height)
    return this.DoDefault
}
```

---

### `.Free()`

Call `.Free()` to unhook the custom window procedure and **release all
allocated memory** related to the injection. Although Yako already
cleans up when your script exits, you can use this function to explicitly
unhook the window.

```ahk
Notepad.Free() ; stop listening to Notepad's window messages
```

---

### `.ReadObject(StructClass, Ptr)`

Use `.ReadObject()` to **safely read a struct from the remote process**.
Trying to access memory from another process without special logic will
trigger an access violation, which causes the script to crash unexpectedly.
This method wraps the required `ReadProcessMemory` logic and reads data into
your `StructClass` type.

```ahk
...
static Sizing(Callback) {
    this.OnMessage(WM_SIZING := 0x0214, (this, wParam, lParam) {
        WindowEdge := wParam
        Bounds := this.ReadObject(RECT, lParam)
        return Callback(this, Bounds, WindowEdge)
    })
}
...
```

---

### The Ready-to-use `Yako.Gui` Class

You don't need to manually set up message hooks for every common event,
that's where the `Yako.Gui` class comes into play. It contains many different
types of registration methods, so you don't need to care about how Windows
implements its messages.

You can extend `Yako.Gui` and just define the non-static methods you care
about.

```ahk
class Notepad extends Yako.Gui {
    class MessageHandler {
        Destroy() { ... }
        Move(x, y) { ... }
        Size(Width, Height, ResizeType) { ... }
    }
}
```
