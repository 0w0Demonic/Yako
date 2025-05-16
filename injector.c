// ,-.    ,_~*, /
//    \ ,´_, ´ /        _,
//     l (_|, /__   .*´  l\  _@&^""-._o
//  <_/     `/\  (o)      `*$m^
// 
// https://www.github.com/0w0Demonic/Yako
// - injector.c

#include <windows.h>
#include <stdio.h>

// return values
#define INJECT_SUCCESS           0
#define INJECT_ERR_OPENPROCESS   1
#define INJECT_ERR_ALLOC         2
#define INJECT_ERR_WRITE         3
#define INJECT_ERR_THREAD        4
#define INJECT_ERR_DLL_NOT_FOUND 5
#define INJECT_ERR_GETPROC       6

// struct that we need for `windowProc\init()`
typedef struct {
    HWND hTarget;
    HWND hAhkScript;
} InitData;

// calls a function from an external process
BOOL callRemote(HANDLE hProcess, FARPROC fn, void* hData, size_t reqSize)
{
    BOOL success = FALSE;
    void* pRemote = VirtualAllocEx(hProcess, NULL, reqSize, MEM_COMMIT, PAGE_READWRITE);
    if (!pRemote) {
        return FALSE;
    }

    if (WriteProcessMemory(hProcess, pRemote, hData, reqSize, NULL)) {
        HANDLE hThread = CreateRemoteThread(hProcess, NULL, 0,
                (LPTHREAD_START_ROUTINE)fn, pRemote, 0, NULL);
        if (hThread) {
            WaitForSingleObject(hThread, INFINITE);
            CloseHandle(hThread);
            success = TRUE;
        }
    }

    VirtualFreeEx(hProcess, pRemote, 0, MEM_RELEASE);
    return success;
}

// injects the given window with a new subclass procedure, forwarding each
// message to an AutoHotkey script for handling messages.
// 
// hTarget    - the target window
// hAhkScript - AutoHotkey script to forward messages to
// dllPath    - file path to `windowProc.dll`
__declspec(dllexport)
int inject(HWND hTarget, HWND hAhkScript, LPWSTR dllPath)
{
    // open process of target window
    DWORD targetPID;
    GetWindowThreadProcessId(hTarget, &targetPID);
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, targetPID);
    if (!hProcess) {
        return INJECT_ERR_OPENPROCESS;
    }

    // load library from the external process
    size_t dllSize = (wcslen(dllPath) + 1) * sizeof(WCHAR);
    if (!callRemote(hProcess, (FARPROC)LoadLibraryW, dllPath, dllSize)) {
        CloseHandle(hProcess);
        return INJECT_ERR_THREAD;
    }

    // load windowProc.dll locally
    HMODULE hLocalDll = LoadLibraryW(dllPath);
    if (!hLocalDll) {
        CloseHandle(hProcess);
        return INJECT_ERR_DLL_NOT_FOUND;
    }

    // get entry point of windowProc.dll/init()
    FARPROC InitProc = GetProcAddress(hLocalDll, "init");
    if (!InitProc) {
        FreeLibrary(hLocalDll);
        CloseHandle(hProcess);
        return INJECT_ERR_GETPROC;
    }

    // call windowProc.dll/init() from external thread
    InitData data = { hTarget, hAhkScript };
    BOOL ok = callRemote(hProcess, InitProc, &data, sizeof(InitData));
    FreeLibrary(hLocalDll);
    CloseHandle(hProcess);
    return (ok) ? INJECT_SUCCESS : INJECT_ERR_THREAD;
}