/**
 * ```
 *  ,-.    ,_~*, /
 *     \ ,´_, ´ /        _,
 *      l (_|, /__   .*´  l\  _@&^""-._o
 *   <_/     `/\  (o)      `*$m^
 * ```
 * https://www.github.com/0w0Demonic/Yako
 */
class Gui extends Yako {
class MessageHandler {
    /**
     * Sent when the window is being destroyed.
     * 
     * - return value: always `DoDefault`
     * 
     * @example
     * Destroy() {
     *     ExitApp()
     * }
     */
    static Destroy(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_DESTROY := 0x0002, (GuiObj, wParam, lParam) {
            Callback(GuiObj)
            return GuiObj.DoDefault
        })
    }

    /**
     * Sent after the window has been moved.
     * 
     * - x: x-coordinate of client area
     * - y: y-coordinate of client area
     * 
     * - return value: `0` or `DoDefault`
     * 
     * @example
     * Move(x, y) {
     *     ToolTip("moving... " . x . " " . y)
     * }
     */
    static Move(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_MOVE := 0x0003, (GuiObj, wParam, lParam) {
            x := lParam & 0xFFFF
            y := (lParam >>> 16) & 0xFFFF
            return Callback(GuiObj, x, y)
        })
    }

    /**
     * Sent after the window's size has changed.
     * 
     * - Width: new width of client area
     * - Height: new height of client area
     * 
     * - return value: `0` or `DoDefault`
     * 
     * @example
     * Size(Width, Height, ResizeType) {
     *     ToolTip("resizing... " . Width . " " . Height)
     * }
     * 
     * ; "ResizeType" values
     * Restored := 0, Minimized := 1, Maximized := 2
     * MaxShow  := 3, MaxHide   := 4
     */
    static Size(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SIZE := 0x0005, (GuiObj, wParam, lParam) {
            Width := lParam & 0xFFFF
            Height := (lParam >>> 16) & 0xFFFF
            return Callback(GuiObj, Width, Height, wParam)
        })
    }

    /**
     * Sent to the window when being activated or deactivated.
     * 
     * - Active: whether the windw was activated or deactivated
     * - OtherHwnd: other window which was activated or deactivated
     * 
     * - return value: `0` or `DoDefault`
     * 
     * @example
     * Activate(Active, OtherHwnd) {
     *     if (Active) {
     *         ToolTip("window activated")
     *     } else {
     *         ToolTip("window deactivated")
     *     }
     * }
     * 
     * ; "Active" values
     * Inactive := 0, Active := 1, ClickActive := 2
     */
    static Activate(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_ACTIVATE := 0x0006, Callback)
    }

    /**
     * Sent to the window after it has gained the keyboard focus.
     * 
     * - PreviousHwnd: handle to the window that lost the keyboard focus
     * 
     * - return value: `0` or `DoDefault`
     * 
     * @example
     * Focus(Previous) {
     *     ToolTip("gained keyboard focus. previous window: " . Previous)
     * }
     */
    static Focus(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SETFOCUS := 0x0007, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
    }

    /**
     * Sent to the window immediate before it loses the keyboard focus.
     * 
     * - NextHwnd: handle to the window that receives the keyboard focus
     * 
     * - return value: `0` or `DoDefault`
     * 
     * @example
     * FocusLost(Next) {
     *     ToolTip("lost keyboard focus. next window: " . Next)
     * }
     */
    static FocusLost(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_KILLFOCUS := 0x0008, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, wParam)
        })
    }

    /**
     * Sent to the window that the user is resizing.
     * TODO docs
     * 
     * Bounds: RECT structure with screen coordinates
     * Edge: the edge of the window being sized
     * 
     * @example
     * Sizing(Bounds, Edge) {
     *     ToolTip(Format("resizing... {} {} {} {}",
     *             Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom))
     * }
     * 
     * ; "Edge" values
     * Left     := 1, Right  := 2, Top        := 3, TopLeft     := 4
     * TopRight := 5, Bottom := 6, BottomLeft := 7, BottomRight := 8
     */
    static Sizing(Callback) {
        GetMethod(Callback)
        this.OnMessage(WM_SIZING := 0x0214, (GuiObj, wParam, lParam) {
            return Callback(GuiObj, GuiObj.ReadObject(RECT, lParam), wParam)
        })
    }
} ; class MessageHandler
} ; class Gui


