// https://www.github.com/0w0Demonic/Tanuki
// - windowProc2.c
#include <windows.h>
#include <stdio.h>
#include <commctrl.h>

#define WM_TANUKIMESSAGE 0x3CCC // message number of our callbacks

HWND g_hAhkScript = NULL; // handle of the AHK script
HWND g_hTarget = NULL; // handle of our target to subclass
HMODULE g_hModule = NULL; // handle of this DLL
HANDLE g_hAhkProcess = NULL; // process handle of AHK script
void* g_pRemote = NULL; // pointer to external buffer for TanukiMessage

typedef struct {
    HWND hTarget;
    HWND hAhkScript;
} InitData;

typedef struct {
    UINT msg;
    WPARAM wParam;
    LPARAM lParam;
    LRESULT lResult;
    BOOL handled;
} TanukiMessage, *lpTanukiMessage;

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

    // allocate memory inside AHK script large enough to hold one TanukiMessage
    if (!g_pRemote) {
        g_pRemote = VirtualAllocEx(g_hAhkProcess, NULL, sizeof(TanukiMessage),
                        MEM_COMMIT, PAGE_READWRITE);
    }

    // remove subclass if application is destroyed
    if (uMsg == WM_NCDESTROY) {
        RemoveWindowSubclass(hwnd, SubclassProc, uIdSubclass);
        CloseHandle(g_hAhkProcess);
        VirtualFreeEx(g_hAhkProcess, g_pRemote, 0, MEM_RELEASE);
        return DefSubclassProc(hwnd, uMsg, wParam, lParam);
    }
    
    // WPARAM - HWND
    // LPARAM - TanukiMessage*
    TanukiMessage m = { uMsg, wParam, lParam, 0, FALSE };
    WriteProcessMemory(g_hAhkProcess, g_pRemote, &m, sizeof(TanukiMessage), NULL);
    SendMessage(g_hAhkScript, WM_TANUKIMESSAGE, (WPARAM)hwnd, (LPARAM)g_pRemote);
    ReadProcessMemory(g_hAhkProcess, g_pRemote, &m, sizeof(TanukiMessage), NULL);

    // return LRESULT of message if handled, otherwise call next proc
    return (m.handled) ? m.lResult
                       : DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

LRESULT CALLBACK WndHook(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode >= 0) {
        CWPSTRUCT *cwp = (CWPSTRUCT*)lParam;

        if (cwp->hwnd == g_hTarget) {
            SetWindowSubclass(cwp->hwnd, SubclassProc, 0, 0);
        }
    }
    return CallNextHookEx(NULL, nCode, wParam, lParam);
}

DWORD WINAPI HookThread(LPVOID lpParam) {
    DWORD targetThreadId = (DWORD)(uintptr_t)lpParam;

    HHOOK hook = SetWindowsHookEx(
        WH_CALLWNDPROC,
        WndHook,
        g_hModule,
        targetThreadId
    );

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    UnhookWindowsHookEx(hook);
    return 0;
}

__declspec(dllexport)
void init(InitData *data)
{
    INITCOMMONCONTROLSEX icex = { sizeof(icex), ICC_WIN95_CLASSES };
    InitCommonControlsEx(&icex);

    g_hAhkScript = data->hAhkScript;
    g_hTarget    = data->hTarget;

    DWORD targetThreadId = GetWindowThreadProcessId(g_hTarget, NULL);
    CreateThread(NULL, 0, HookThread, (LPVOID)(uintptr_t)targetThreadId, 0, NULL);
}