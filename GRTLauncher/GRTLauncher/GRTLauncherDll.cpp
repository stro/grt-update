#include "pch.h"

#include <windows.h>
#include <detours/detours.h>

static VOID(WINAPI* TrueGetSystemTime)(LPSYSTEMTIME lpSystemTime) = GetSystemTime;
static VOID(WINAPI* TrueGetLocalTime)(LPSYSTEMTIME lpLocalTime) = GetLocalTime;

void WINAPI FixedGetSystemTime(LPSYSTEMTIME lpSystemTime) {
	lpSystemTime->wYear = 2021;
	lpSystemTime->wMonth = 1;
	lpSystemTime->wDay = 1;
	lpSystemTime->wHour = 0;
	lpSystemTime->wMinute = 0;
	lpSystemTime->wSecond = 0;
	lpSystemTime->wMilliseconds = 0;
	lpSystemTime->wDayOfWeek = 1;
	return;
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD dwReason, LPVOID reserved)
{
    if (DetourIsHelperProcess()) {
        return TRUE;
    }

    if (dwReason == DLL_PROCESS_ATTACH) {
        DetourRestoreAfterWith();

        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());
        DetourAttach(&(PVOID&)TrueGetSystemTime, FixedGetSystemTime);
        DetourAttach(&(PVOID&)TrueGetLocalTime, FixedGetSystemTime);
        DetourTransactionCommit();
    }
    else if (dwReason == DLL_PROCESS_DETACH) {
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());
        DetourDetach(&(PVOID&)TrueGetSystemTime, FixedGetSystemTime);
        DetourDetach(&(PVOID&)TrueGetLocalTime, FixedGetSystemTime);
        DetourTransactionCommit();
    }
    return TRUE;
}
    