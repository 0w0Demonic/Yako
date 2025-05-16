// ,-.    ,_~*, /
//    \ ,´_, ´ /        _,
//     l (_|, /__   .*´  l\  _@&^""-._o
//  <_/     `/\  (o)      `*$m^
// 
// https://www.github.com/0w0Demonic/Yako
// - windowProc.c

#include <windows.h>
#include <stdio.h>
#include <commctrl.h>

// message number of our callbacks
#define WM_YAKO_MESSAGE  0x3CCC
#define WM_YAKO_FREEPROC 0x4CCC

HWND g_hAhkScript = NULL;    // handle of the AHK script
HWND g_hTarget = NULL;       // handle of our target to subclass
HMODULE g_hModule = NULL;    // handle of this DLL
HANDLE g_hAhkProcess = NULL; // process handle of AHK script
void* g_pRemote = NULL;      // external buffer that fits one YakoMessage struct

HANDLE g_hHookThread = NULL; // thread handle of the window hook
HHOOK g_wndHook = NULL;      // window hook needed for injection of subclass

volatile BOOL g_stopThread = FALSE; // flag for stopping the window hook thread

// holds data for init()
typedef struct {
    HWND hTarget;
    HWND hAhkScript;
} InitData;

// message that we pass around between the window and AHK script
typedef struct {
    UINT msg;        // message number
    WPARAM wParam;   // wParam
    LPARAM lParam;   // lParam
    LRESULT lResult; // the result we give back from inside AHK
    BOOL handled;    // whether the message should be deferred to the next proc
} YakoMessage, *lpYakoMessage;

BOOL APIENTRY DllMain(
        HMODULE hModule, DWORD reason,
        WPARAM wParam, LPARAM lParam
);

LRESULT CALLBACK SubclassProc(
        HWND hwnd, UINT uMsg,
        WPARAM wParam, LPARAM lParam,
        UINT_PTR uIdSubclass, DWORD_PTR dwRefData
);

__declspec(dllexport) void init(InitData *data);

DWORD WINAPI HookThread(LPVOID lpParam);

/******************************************************************************/

BOOL APIENTRY DllMain(
        HMODULE hModule, DWORD reason,
        WPARAM wParam, LPARAM lParam)
{
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        DisableThreadLibraryCalls(hModule);
        g_hModule = hModule;
        break;
    case DLL_PROCESS_DETACH:
        CloseHandle(g_hAhkProcess);
        VirtualFreeEx(g_hAhkProcess, g_pRemote, 0, MEM_RELEASE);
        break;
    }
    return TRUE;
}

LRESULT CALLBACK SubclassProc(
        HWND hwnd, UINT uMsg,
        WPARAM wParam, LPARAM lParam,
        UINT_PTR uIdSubclass, DWORD_PTR dwRefData)
{
    // find out the process handle to AHK script
    if (!g_hAhkProcess) {
        DWORD ahkPID;
        GetWindowThreadProcessId(g_hAhkScript, &ahkPID);
        g_hAhkProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, ahkPID);
    }

    // allocate memory inside AHK script large enough to hold one YakoMessage
    if (!g_pRemote) {
        g_pRemote = VirtualAllocEx(g_hAhkProcess, NULL, sizeof(YakoMessage),
                        MEM_COMMIT, PAGE_READWRITE);
    }


    // remove subclass if application is destroyed
    switch (uMsg) {
    case WM_YAKO_FREEPROC:
        if (wParam != WM_YAKO_FREEPROC || lParam != WM_YAKO_FREEPROC) {
            break;
        }
        // fall-through
    case WM_NCDESTROY:
        RemoveWindowSubclass(hwnd, SubclassProc, uIdSubclass);
        CloseHandle(g_hAhkProcess);
        VirtualFreeEx(g_hAhkProcess, g_pRemote, 0, MEM_RELEASE);
        return DefSubclassProc(hwnd, uMsg, wParam, lParam);
    }

    // WPARAM - HWND
    // LPARAM - YakoMessage*
    YakoMessage m = { uMsg, wParam, lParam, 0, FALSE };
    WriteProcessMemory(g_hAhkProcess, g_pRemote, &m, sizeof(YakoMessage), NULL);
    SendMessage(g_hAhkScript, WM_YAKO_MESSAGE, (WPARAM)hwnd, (LPARAM)g_pRemote);
    ReadProcessMemory(g_hAhkProcess, g_pRemote, &m, sizeof(YakoMessage), NULL);

    // return LRESULT of message if handled, otherwise call next proc
    return (m.handled) ? m.lResult
                       : DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

// the hook procedure which we use to set the subclass of the window
LRESULT CALLBACK WndHook(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode >= 0) {
        CWPSTRUCT *cwp = (CWPSTRUCT*)lParam;

        if (cwp->hwnd == g_hTarget) {
            SetWindowSubclass(cwp->hwnd, SubclassProc, 0, 0);
            UnhookWindowsHookEx(g_wndHook);
            g_stopThread = TRUE;
            DWORD threadId = GetThreadId(g_hHookThread);
            PostThreadMessage(threadId, WM_QUIT, 0, 0);
            WaitForSingleObject(g_hHookThread, INFINITE);
        }
    }
    return CallNextHookEx(NULL, nCode, wParam, lParam);
}

// entry point for the thread that creates a hook procedure for the window
DWORD WINAPI HookThread(LPVOID lpParam) {
    DWORD targetThreadId = (DWORD)(uintptr_t)lpParam;

    g_wndHook = SetWindowsHookEx(
        WH_CALLWNDPROC,
        WndHook,
        g_hModule,
        targetThreadId
    );

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0) && !g_stopThread) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    UnhookWindowsHookEx(g_wndHook);
    return 0;
}

// initializes the subclass procedure. To be able to inject the subclass proc,
// we must call `SetWindowSubclass()` from both the same thread and the same
// process. For that, we use a hook procedure (`SetWindowsHookEx()`).
__declspec(dllexport)
void init(InitData *data)
{
    INITCOMMONCONTROLSEX icex = { sizeof(icex), ICC_WIN95_CLASSES };
    InitCommonControlsEx(&icex);

    g_hAhkScript = data->hAhkScript;
    g_hTarget    = data->hTarget;

    DWORD targetThreadId = GetWindowThreadProcessId(g_hTarget, NULL);
    g_hHookThread = CreateThread(NULL, 0, HookThread, (LPVOID)(uintptr_t)targetThreadId, 0, NULL);
}