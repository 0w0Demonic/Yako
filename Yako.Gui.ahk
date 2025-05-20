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
     * **Return Value**:
     *   - always `this.DoDefault` to ensure proper cleanup
     * 
     * @example
     * Destroy() {
     *     ExitApp()
     * }
     */
    static Destroy(Callback) {
        this.OnMessage(WM_DESTROY := 0x0002, (this, wParam, lParam) {
            Callback(this)
            return this.DoDefault
        })
    }

    /**
     * Sent after the window has been moved.
     * 
     * **Parameters**:
     * - x: x-coordinate of client area
     * - y: y-coordinate of client area
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * Move(x, y) {
     *     ToolTip("moving... " . x . " " . y)
     * }
     */
    static Move(Callback) {
        this.OnMessage(WM_MOVE := 0x0003, (this, wParam, lParam) {
            x := lParam & 0xFFFF
            y := (lParam >>> 16) & 0xFFFF
            return Callback(this, x, y)
        })
    }

    /**
     * Sent after the window's size has changed.
     * 
     * **Parameters**:
     * - Width: new width of client area
     * - Height: new height of client area
     * 
     * **Return Value**:
     * - `0` to consume the message
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
        this.OnMessage(WM_SIZE := 0x0005, (this, wParam, lParam) {
            Width := lParam & 0xFFFF
            Height := (lParam >>> 16) & 0xFFFF
            return Callback(this, Width, Height, wParam)
        })
    }

    /**
     * Sent to the window when being activated or deactivated.
     * 
     * **Parameters**:
     * - Active: whether the windw was activated or deactivated
     * - OtherHwnd: other window which was activated or deactivated
     * 
     * **Return Value**:
     * - `0` to consume the message
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
        this.OnMessage(WM_ACTIVATE := 0x0006, Callback)
    }

    /**
     * Sent to the window after it has gained the keyboard focus.
     * 
     * **Parameters**:
     * - PreviousHwnd: handle to the window that lost the keyboard focus
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * Focus(Previous) {
     *     ToolTip("gained keyboard focus. previous window: " . Previous)
     * }
     */
    static SetFocus(Callback) {
        this.OnMessage(WM_SETFOCUS := 0x0007, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    /**
     * Sent to the window immediate before it loses the keyboard focus.
     * 
     * **Parameters**:
     * - NextHwnd: handle to the window that receives the keyboard focus
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * FocusLost(Next) {
     *     ToolTip("lost keyboard focus. next window: " . Next)
     * }
     */
    static KillFocus(Callback) {
        this.OnMessage(WM_KILLFOCUS := 0x0008, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    /**
     * Sent when the window is enabled or disabled.
     * 
     * **Parameters**:
     * - WasEnabled: enabled status of the window
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * Enable(WasEnabled) {
     *     ToolTip(WasEnabled ? "enabled..."
     *                        : "disabled...")
     * }
     */
    static Enable(Callback) {
        this.OnMessage(WM_ENABLE := 0x000A, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    /**
     * Sent when an application allows or prevents changes in the window to
     * be redrawn.
     * 
     * **Parameters**:
     * - OnOff: whether the content can be redrawn
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * Redraw(OnOff) {
     *     ToolTip((OnOff ? "allow" : "prevent") . " redrawing")
     * }
     */
    static Redraw(Callback) {
        this.OnMessage(WM_SETREDRAW := 0x000B, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    ; TODO missing messages

    /**
     * Sent as a signal that the window should terminate.
     * 
     * @example
     * Close() {
     *     Result := MsgBox("Are you sure you want to quit?", "Notepad", 0x0001)
     *     return (Result = "OK") ? this.DoDefault : 0
     * }
     */
    static Close(Callback) {
        this.OnMessage(WM_CLOSE := 0x0010, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    /**
     * TODO
     */
    static QueryEndSession(Callback) {
        
    }

    /**
     * Sent to an icon when the user requests that the window be restored to
     * its previous size and position.
     * 
     * **Return Value**:
     * - `true` if the icon can be opened
     * - `false` to prevent the icon from being opened
     * 
     * @example
     * QueryOpen() {
     *     ; open in 50% of cases, for the sake of being annoying
     *     return Random(true, false)
     * }
     */
    static QueryOpen(Callback) {
        this.OnMessage(WM_QUERYOPEN := 0x0013, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    /**
     * TODO is this even called?
     * Sent to inform the application whether the session is ending.
     * 
     * **Parameters**:
     * - Reason: the reason that the session is ending (bit flags)
     * 
     * - WasCanceled:
     *   - `true`, if the shutdown was canceled
     *   - `false` otherwise
     * 
     * TODO maybe wrap this in an object
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * EndSession(Reason, WasCanceled) {
     *     ToolTip(Reason)
     * }
     * 
     * ; `Reason` bit flags
     * Shutdown := 0, Restart := 0
     * CloseApp := 0x00000001, Critical := 0x40000000, Logoff := 0x80000000
     */
    static EndSession(Callback) {
        this.OnMessage(WM_ENDSESSION := 0x0016, (this, wParam, lParam) {
            return Callback(this, lParam, !wParam)
        })
    }

    /**
     * TODO problems if I don't use PostMessage to handle this?
     */
    static Quit(Callback) {
        this.OnMessage(WM_QUIT := 0x0012, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    ; TODO EraseBackground() ?
    ; TODO SysColorChange() ?
    
    /**
     * TODO does target receive this message?
     * Sent to the window when it is about to be hidden or shown.
     * 
     * **Parameters**:
     * - IsShown: `true`, if the window is being shown, otherwise `false`
     * - Status: the status of the window being shown
     * 
     * **Return Value**:
     * - `0` to consume the message
     * 
     * @example
     * ShowWindow(IsShown, Status) {
     *     
     * }
     * 
     * ; `Status` enumeration
     * CalledFrom_ShowWindow := 0
     * ParentClosing := 1, OtherZoom := 2, ParentOpening := 3, OtherUnzoom := 4
     */
    static ShowWindow(Callback) {
        this.OnMessage(WM_SHOWWINDOW := 0x0018, Callback)
    }

    /**
     * TODO
     */
    static SettingChange(Callback) {

    }

    /**
     * TODO
     */
    static DeviceModeChange(Callback) {

    }

    /**
     * 
     */
    static ActivateApp(Callback) {
        this.OnMessage(WM_ACTIVATEAPP := 0x001C, Callback)
    }

    /**
     * 
     */
    static FontChange(Callback) {
        this.OnMessage(WM_FONTCHANGE := 0x001D, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    /**
     * TODO is this still used?
     */
    static TimeChange(Callback) {
        this.OnMessage(WM_TIMECHANGE := 0x001E, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    static CancelMode(Callback) {

    }

    /**
     * Sent to the window if the mouse causes the cursor to move within the
     * window and mouse input is not captured.
     * 
     * **Parameters**:
     * - HitTest: hit-test result for the cursor position
     * - MsgNumber: message that triggered this event
     * - Hwnd: handle to the window that contains the cursor
     * 
     * **Return Value**:
     * - `true` to halt further processing
     * - `false` or `this.DoDefault` to continue
     * 
     * @example
     * SetCursor(HitTest, MsgNumber, Hwnd) {
     *     if (HitTest == 2) { ; caption
     *         ToolTip("hovering over caption...")
     *     } else {
     *         ToolTip("hovering outside of caption...")
     *     }
     * }
     */
    static SetCursor(Callback) {
        this.OnMessage(WM_SETCURSOR := 0x0020, (this, wParam, lParam) {
            HitTest := lParam & 0xFFFF
            MsgNumber := (lParam >>> 16) & 0xFFFF
            return Callback(this, HitTest, MsgNumber, wParam)
        })
    }

    static MouseActivate(Callback) {

    }

    static ChildActivate(Callback) {

    }

    static GetMinMaxInfo(Callback) {

    }

    static PaintIcon(Callback) {

    }

    static IconEraseBackground(Callback) {

    }

    static NextDialogControl(Callback) {

    }

    static SpoolerStatus(Callback) {

    }

    static DrawItem(Callback) {

    }

    static MeasureItem(Callback) {

    }

    static DeleteItem(Callback) {

    }

    static VKeyToItem(Callback) {

    }

    static CharToItem(Callback) {

    }

    static SetFont(Callback) {

    }

    static GetFont(Callback) {

    }

    static SetHotkey(Callback) {

    }

    static GetHotkey(Callback) {

    }

    static QueryDragIcon(Callback) {

    }

    static CompareItem(Callback) {

    }

    static GetObject(Callback) {

    }

    static Compacting(Callback) {

    }

    static CommonNotify(Callback) {

    }

    static WindowPosChanging(Callback) {

    }

    static WindowPosChange(Callback) {

    }

    static Power(Callback) {

    }

    static Notify(Callback) {

    }

    static InputLangChangeRequest(Callback) {

    }

    static InputLangChange(Callback) {

    }

    static TrainingCard(Callback) {

    }

    static Help(Callback) {

    }

    static UserChanged(Callback) {

    }

    static NotifyFormat(Callback) {

    }

    /**
     * TODO
     */
    static ContextMenu(Callback) {
        this.OnMessage(WM_CONTEXTMENU := 0x007B, (this, wParam, lParam) {
            x := lParam & 0xFFFF
            y := (lParam >>> 16) & 0xFFFF
            return Callback(this, wParam, x, y)
        })
    }

    static StyleChanging(Callback) {

    }

    static StyleChanged(Callback) {

    }

    static DisplayChange(Callback) {

    }

    static GetIcon(Callback) {

    }

    static SetIcon(Callback) {

    }

    static NcCreate(Callback) {

    }

    static NcDestroy(Callback) {

    }

    static NcCalcSize(Callback) {

    }

    static NcHitTest(Callback) {

    }

    static NcPaint(Callback) {

    }

    static NcActivate(Callback) {

    }

    static GetDialogCode(Callback) {

    }

    static SyncPaint(Callback) {

    }

    /**
     * Posted to the window when the cursor is moved within the nonclient area
     * of the window.
     */
    static NcMouseMove(Callback) {
        this.OnMessage(WM_NCMOUSEMOVE := 0x00A0, (this, wParam, lParam) {
            x := lParam & 0xFFFF
            y := (lParam >>> 16) & 0xFFFF
            Callback(this, x, y, wParam)
        })
    }

    static NcLButtonDown(Callback) {

    }

    static NcLButtonUp(Callback) {

    }

    static NcLButtonDoubleClick(Callback) {

    }

    static NcRButtonDown(Callback) {

    }

    static NcRButtonUp(Callback) {

    }

    static NcRButtonDoubleClick(Callback) {

    }

    static NcMButtonDown(Callback) {

    }

    static NcMButtonUp(Callback) {

    }

    static NcMButtonDoubleClick(Callback) {

    }
    
    static NcXButtonDown(Callback) {

    }

    static NcXButtonUp(Callback) {

    }

    static NcXButtonDoubleClick(Callback) {

    }

    static InputDeviceChange(Callback) {

    }

    static Input(Callback) {

    }

    static KeyDown(Callback) {

    }

    static KeyUp(Callback) {

    }

    static Char(Callback) {

    }

    static DeadChar(Callback) {

    }

    static SysKeyDown(Callback) {

    }

    static SysKeyUp(Callback) {

    }

    static SysChar(Callback) {

    }

    static SysDeadChar(Callback) {

    }

    static UniChar(Callback) {

    }

    static KeyLast(Callback) {

    }

    static ImeStartComposition(Callback) {

    }

    static ImeEndComposition(Callback) {

    }

    static ImeComposition(Callback) {

    }

    static InitDialog(Callback) {

    }

    static Command(Callback) {

    }

    static SysCommand(Callback) {

    }

    static Timer(Callback) {

    }

    static HScroll(Callback) {

    }

    static VScroll(Callback) {
        
    }

    static InitMenu(Callback) {
        this.OnMessage(WM_INITMENU := 0x0116, (this, wParam, lParam) {
            return Callback(this, wParam)
        })
    }

    static InitMenuPopup(Callback) {

    }

    static Gesture(Callback) {

    }

    static GestureNotify(Callback) {

    }

    static MenuSelect(Callback) {

    }

    static MenuChar(Callback) {

    }

    static EnterIdle(Callback) {

    }

    static MenuRButtonUp(Callback) {

    }

    static MenuDrag(Callback) {

    }

    static MenuGetObject(Callback) {

    }

    static UnInitMenuPopup(Callback) {

    }

    static MenuCommand(Callback) {

    }

    static ChangeUiState(Callback) {

    }

    static UpdateUiState(Callback) {

    }

    static QueryUiState(Callback) {

    }

    static ColorMsgBox(Callback) {

    }

    static ColorEdit(Callback) {

    }

    static ColorListBox(Callback) {

    }

    static ColorButton(Callback) {

    }

    static ColorDialog(Callback) {

    }

    static ColorScrollBar(Callback) {

    }

    static ColorStatic(Callback) {

    }

    static MouseMove(Callback) {

    }

    static LButtonDown(Callback) {

    }

    static LButtonUp(Callback) {

    }

    static LButtonDoubleClick(Callback) {

    }

    static RButtonDown(Callback) {

    }

    static RButtonUp(Callback) {

    }

    static RButtonDoubleClick(Callback) {

    }

    static MButtonDown(Callback) {

    }

    static MButtonUp(Callback) {

    }

    static MButtonDoubleClick(Callback) {

    }

    static MouseWheel(Callback) {

    }

    static XButtonDown(Callback) {

    }

    static XButtonUp(Callback) {

    }

    static XButtonDoubleClick(Callback) {

    }

    static MouseHWheel(Callback) {

    }

    static ParentNotify(Callback) {

    }

    static EnterMenuLoop(Callback) {

    }

    static ExitMenuLoop(Callback) {

    }

    static NextMenu(Callback) {

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
        this.OnMessage(WM_SIZING := 0x0214, (this, wParam, lParam) {
            return Callback(this, this.ReadObject(RECT, lParam), wParam)
        })
    }

    static CaptureChanged(Callback) {

    }

    static Moving(Callback) {
        this.OnMessage(WM_MOVING := 0x216, (this, wParam, lParam) {
            return Callback(this, this.ReadObject(RECT, lParam))
        })
    }

    static PowerBroadcast(Callback) {

    }

    static DeviceChange(Callback) {

    }

    static MdiCreate(Callback) {

    }

    static MdiDestroy(Callback) {

    }

    static MdiActivate(Callback) {

    }

    static MdiRestore(Callback) {

    }

    static MdiNext(Callback) {

    }

    static MdiMaximize(Callback) {

    }

    static MdiTile(Callback) {

    }

    static MdiCascade(Callback) {

    }

    static MdiIconArrange(Callback) {

    }

    static MdiSetMenu(Callback) {

    }

    static EnterSizeMove(Callback) {
        this.OnMessage(WM_ENTERSIZEMOVE := 0x0231, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    static ExitSizeMove(Callback) {
        this.OnMessage(WM_EXITSIZEMOVE := 0x0232, (this, wParam, lParam) {
            return Callback(this)
        })
    }

    static DropFiles(Callback) {
        
    }

    static MdiRefreshMenu(Callback) {

    }

    static PointerDeviceChange(Callback) {

    }

    static PointerDeviceInRange(Callback) {

    }

    static PointerDeviceOutOfRange(Callback) {

    }

    static Touch(Callback) {

    }

    static NcPointerUpdate(Callback) {

    }

    static NcPointerDown(Callback) {

    }

    static NcPointerUp(Callback) {

    }

    static PointerUpdate(Callback) {

    }

    static PointerDown(Callback) {

    }

    static PointerUp(Callback) {

    }

    static PointerEnter(Callback) {

    }

    static PointerLeave(Callback) {

    }

    static PointerActivate(Callback) {

    }

    static PointerCaptureChanged(Callback) {

    }

    static TouchHitTesting(Callback) {

    }

    static PointerWheel(Callback) {

    }

    static PointerHWheel(Callback) {

    }

    static PointerRoutedTo(Callback) {

    }

    static PointerRoutedAway(Callback) {

    }

    static PointerRoutedReleased(Callback) {

    }

    static ImeSetContext(Callback) {

    }

    static ImeNotify(Callback) {

    }

    static ImeCompositionFull(Callback) {

    }

    static ImeSelect(Callback) {

    }

    static ImeChar(Callback) {

    }

    static ImeRequest(Callback) {

    }

    static ImeKeyDown(Callback) {

    }

    static ImeKeyUp(Callback) {

    }

    static MouseHover(Callback) {

    }

    static MouseLeave(Callback) {

    }

    static NcMouseHover(Callback) {

    }

    static NcMouseLeave(Callback) {

    }

    static WtsSessionChange(Callback) {

    }

    static DpiChanged(Callback) {

    }

    static DpiChangedBeforeParent(Callback) {

    }

    static DpiChangedAfterParent(Callback) {

    }

    static GetDpiScaledSize(Callback) {

    }


    static Cut(Callback) {

    }

    static Copy(Callback) {

    }

    static Paste(Callback) {

    }

    static Clear(Callback) {

    }

    static Undo(Callback) {

    }

    static RenderFormat(Callback) {

    }

    static RenderAllFormats(Callback) {

    }

    static DestroyClipboard(Callback) {

    }

    static DrawClipboard(Callback) {

    }

    static PaintClipboard(Callback) {

    }

    static VScrollClipboard(Callback) {

    }

    static SizeClipboard(Callback) {

    }

    static AskClipboardFormatName(Callback) {

    }

    static ChangeClipboardChain(Callback) {

    }

    static HScrollClipboard(Callback) {

    }

    static QueryNewPalette(Callback) {

    }

    static PaletteIsChanging(Callback) {

    }

    static PaletteChanged(Callback) {

    }

    static Hotkey(Callback) {

    }


    static Print(Callback) {

    }

    static PrintClient(Callback) {

    }


    static AppCommand(Callback) {
        this.OnMessage(WM_APPCOMMAND := 0x319, (this, wParam, lParam) {
            Command := (lParam >>> 16) & ~0xF000
            Device  := (lParam >>> 16) & 0xF000
            Keys    := ModifierKeys(lParam & 0xFFFF)
            return Callback(this, Command, Device, Keys)
        })
    }

    static ThemeChanged(Callback) {

    }

    static ClipboardUpdate(Callback) {

    }

    static DwmCompositionChanged(Callback) {

    }

    static DwnNcRenderingChanged(Callback) {

    }

    static DwmColorizationColorChanged(Callback) {

    }

    static DwmWindowMaximizedChange(Callback) {

    }

    static DwmSendIconicThumbnail(Callback) {

    }

    static DwnSendIconicLivePreviewBitmap(Callback) {

    }

    static GetTitleBarInfoEx(Callback) {

    }
} ; class MessageHandler
} ; class Gui