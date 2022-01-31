// GRTLauncher.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>

#include <stdio.h>
#include <Windows.h>

#include <detours/detours.h>

const WORD goodOldYear = 2021;
const WORD goodOldMonth = 1;

int main()
{
    STARTUPINFO si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    wchar_t exeName[] = L"GordonsReloadingTool.exe";

    if (!DetourCreateProcessWithDllEx(
        NULL,           // No module name (use command line)
        exeName,        // Command line
        NULL,           // Process handle not inheritable
        NULL,           // Thread handle not inheritable
        FALSE,          // Set handle inheritance to FALSE
        0,              // No creation flags
        NULL,           // Use parent's environment block
        NULL,           // Use parent's starting directory 
        &si,            // Pointer to STARTUPINFO structure
        &pi,            // Pointer to PROCESS_INFORMATION structure
        "GRTLauncherDll.dll",
        NULL
        ))
    {
        printf("CreateProcess failed (%d).\n", GetLastError());
        return 0;
    }

    return 0;
}

