# grt-update
Update helper for Gordons Reloading Tool

## What is it?

It's a simple Perl script to update Gordons Reloading Tool from a ZIP file. It updates the existing installation while keeping configuration files intact.
A Win32 executable is provided so it can be run without Perl installed on a Windows machine.

## How to run

### Windows

#### Pre-compiled binary

Just run the exe file. 

NOTE! As of January 2021, on Windows 7, a built-in anti-virus detects the executable as a generic Trojan. It's a false positive and it was submitted to Microsoft for review: https://www.microsoft.com/en-us/wdsi/submission/6c2ce48e-7b2b-4db3-92bc-7cd68c32a8b4

#### Using Strawberry Perl

You'll need Strawberry Perl to compile library prerequisites and run the script. After installing Strawberry Perl with MinGW (https://strawberryperl.com/), you need to install necessary libraries by running:

    cpan Config::Tiny Prima Win32::File::VersionInfo Win32::Process::List

Then run the grt-update.pl file.

#### Compiling to exe

If you need to run it on multiple machines and don't want to install Perl and libraries everywhere, you can compile it yourself. Just run make_exe.cmd and it will create an executable for you.

### Linux

Unfortunately, I don't have a Linux machine with X11 at the moment. Feel free to send me patches. 

## User Manual

First, you need to download a new version of GRT, either from the website or from Patreon. Your browser will save it in Downloads directory.
After running the update tool, you'll see a pretty simple GUI window.

Press Ctrl+O to open ZIP file. By default, the Open File dialog will open your default user downloads folder. Select the version you want to install and click "Open".

Installation directory by default is pointing to your LocalAppData. If you already installed GRT in some other place and want to coninue using it, type the existing path; otherwise, move on.

Press "Install" button. The tool will install the new version, and also will keep your existing configuration files (for both GRT and plugins).

The tool will not install when:

* GordonsReloadingTool.exe is already running: you'll need to exit the program.
* The version you're trying to install is already installed
* The version you're trying to install would downgrade the existing installation
* ZIP file is corrupted.

As soon as everything is installed (it will take less than 10 seconds), you may click "Exit" or press Alt+X.
