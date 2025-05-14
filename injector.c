// https://www.github.com/0w0Demonic/Tanuki
// - injector2.c

#include <windows.h>
#include <stdio.h>

#define INJECT_SUCCESS           0
#define INJECT_ERR_OPENPROCESS   1
#define INJECT_ERR_ALLOC         2
#define INJECT_ERR_WRITE         3
#define INJECT_ERR_THREAD        4
#define INJECT_ERR_DLL_NOT_FOUND 5
#define INJECT_ERR_GETPROC       6

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

__declspec(dllexport)
int inject(HWND hTarget, HWND hAhkScript, LPWSTR dllPath)
{
    DWORD targetPID;
    GetWindowThreadProcessId(hTarget, &targetPID);
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, targetPID);
    if (!hProcess) {
        return INJECT_ERR_OPENPROCESS;
    }

    size_t dllSize = (wcslen(dllPath) + 1) * sizeof(WCHAR);
    if (!callRemote(hProcess, (FARPROC)LoadLibraryW, dllPath, dllSize)) {
        CloseHandle(hProcess);
        return INJECT_ERR_THREAD;
    }

    HMODULE hLocalDll = LoadLibraryW(dllPath);
    if (!hLocalDll) {
        CloseHandle(hProcess);
        return INJECT_ERR_DLL_NOT_FOUND;
    }

    FARPROC InitProc = GetProcAddress(hLocalDll, "init");
    if (!InitProc) {
        FreeLibrary(hLocalDll);
        CloseHandle(hProcess);
        return INJECT_ERR_GETPROC;
    }

    InitData data = { hTarget, hAhkScript };
    BOOL ok = callRemote(hProcess, InitProc, &data, sizeof(InitData));
    FreeLibrary(hLocalDll);
    CloseHandle(hProcess);
    return (ok) ? INJECT_SUCCESS : INJECT_ERR_THREAD;
}