#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Archive::Zip 1.68;
use Config::Tiny;
use Cwd;
use File::Path;
use File::Spec;
use File::Temp;
use Module::Load;

use Prima;
use Prima::Application;
use Prima::Buttons;
use Prima::ComboBox;
use Prima::Lists;
use Prima::MsgBox;
use Prima::Dialog::FileDialog;

my $is_Win = $^O eq 'MSWin32';

if ($is_Win) {
    load Win32;
    load Win32::File::VersionInfo;
    load Win32::Process::List;
    load Win32::Shortcut;

    load Prima::sys::win32::FileDialog;
}

my $VERSION = '1.008';
my $about_message = sprintf("GordonReloadingTool updater.\nVersion %s.\n\nCopyright (c) 2021 Sergiy Trushel http://sttek.com/\n\nhttps://github.com/stro/grt-update", $VERSION);

my $READ_BUFFER_LENGTH = 16 * 1024; # Multi-part buffer

my $config_file = File::Spec->catfile(Cwd::getcwd, 'grt-update.cfg');

my $config = Config::Tiny->read($config_file, 'utf8') // Config::Tiny->new();

if ($is_Win) {
    $config->{_}->{'DefaultOpenDir'} //= File::Spec->catfile($ENV{'USERPROFILE'}, 'Downloads');
    $config->{_}->{'InstallDir'} //= File::Spec->catfile($ENV{'LOCALAPPDATA'}, 'GordonsReloadingTool');
} else {
    $config->{_}->{'DefaultOpenDir'} //= File::Spec->catfile($ENV{'HOME'}, 'Downloads');
    $config->{_}->{'InstallDir'} //= File::Spec->catfile($ENV{'HOME'}, 'opt', 'GordonsReloadingTool');
}

$config->write($config_file, 'utf8');

my @configuration_files = (
    'GordonsReloadingTool.cfg',
    'plugins/GRTrace/GRTrace.cfg',
    'plugins/GRTrace/plugin-grtrace.cfg',
    'plugins/GRTLab/plugin-grtlab.cfg',
);

my $zip_file;
my $install_dir = $config->{_}->{'InstallDir'};
my $installed_version = 0;

my $window = Prima::MainWindow->new(
    text     => sprintf('GordonReloadingTool updater V%s', $VERSION),
    size     => [ 600, $is_Win ? 250 : 275],
    font     => { size => 8 },
    menuItems => [
                [ '~File' => [
                        ['~Open ZIP File', 'Ctrl+O', '^O', sub { open_zip_file(shift) }],
                        [],
                        ['~About', 'Ctrl+A', '^A', sub { about_message(shift) } ],
                        ['~Exit', 'Alt+X', km::Alt | ord('x'), sub { exit_program(shift) } ],
                ]],
        ],
);


my $zip_file_label = Prima::Label->create(
    text => 'Installation file (Ctrl+~O to open)',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
);

my $zip_file_text = Prima::InputLine->create(
    text => 'No ZIP file selected',
    color => cl::LightRed,
    pack => { fill => 'x', side => 'top', pad => 10 },   
    owner => $window,
    syncPaint => 1,
    onChange => sub { verify_zip_file(shift) },
);

my $install_dir_label = Prima::Label->create(
    text => '~Installation directory',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
);

my $install_dir_text = Prima::InputLine->create(
    text => $install_dir,
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
    onChange => sub { verify_install_dir(shift) },
);

my $status_text = Prima::Label->create(
    text => '',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
    onChange => sub { shift->repaint() },
    syncPaint => 1,
);

my $button_install = Prima::Button->create(
    text => 'Install',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
    onClick => sub { install(shift) },
    enabled => 0,
    default => 1,
    syncPaint => 1,
);

my $button_shortcuts = Prima::Button->create(
    text => 'Create desktop and quick launch icons',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
    onClick => sub { create_shortcuts(shift) },
    enabled => 0,
    syncPaint => 1,
    $is_Win ?
        () :
        ( visible => 0, size => [0, 0])
    ,
);

my $button_exit = Prima::Button->create(
    text     => 'Exit',
    pack => { fill => 'x', side => 'top', pad => 10 },
    owner => $window,
    onClick  => sub { exit_program(shift) },
);

# Initial check of install dir, need to have status. Buttons should be declared before it runs.
verify_install_dir($install_dir_text);
guess_installation_file($install_dir_text, $zip_file_text);

run Prima;

sub save_config {
    my $self = shift;
    $config->write($config_file, 'utf8');
    return 1;
}

sub exit_program {
    my $self = shift;
    save_config();
    return $::application->close();
}

sub about_message {
    my $self = shift;
    message($about_message);
    return 1;
}

sub check_for_updates {
    my $self = shift;
    message('Checking for updates is not implemented yet');
    return 0;
}

sub open_zip_file {
    my $self = shift;
    my @params = (
        directory => $config->{_}->{'DefaultOpenDir'},
        filter => [
                ['GRT Files' => 'Gordons*.*z*'],
                ['ZIP Files' => '*.zip'],
                ['7Z Files' => '*.7z'],
                ['All' => '*']
        ]
    );

    my $open = $is_Win ? Prima::sys::win32::FileDialog->new(@params) : 
                         Prima::Dialog::OpenDialog->new(@params);

    if ($open->execute) {
        $zip_file = $open->fileName;
        $zip_file_text->text($zip_file);
        $zip_file_text->color(cl::Black);
        $button_install->enabled(1);
        return 1;
    } else {
        return 0;
    }
}

sub verify_zip_file {
    my $self = shift;

    $zip_file = $self->text;

    if (-e $zip_file) {
        $self->color(cl::Black);
        $button_install->enabled(1);
        return 1;
    } else {
        $self->color(cl::LightRed);
        $button_install->enabled(0);
        return 0;
    }

}

sub verify_install_dir {
    my $self = shift;

    $install_dir = $self->text;
    $installed_version = 0;

    if (-e $install_dir) {
        if (-d $install_dir) {
            if ($is_Win) {
                my $exe_file = File::Spec->catfile($install_dir, 'GordonsReloadingTool.exe');
                if (-e $exe_file) {
                    $button_shortcuts->enabled(1);

                    if (my $version = Win32::File::VersionInfo::GetFileVersionInfo($exe_file)->{'FileVersion'}) {
                        $installed_version = substr($version, rindex($version, '.') + 1);
                    }
                    if ($installed_version) {
                        $button_shortcuts->enabled(1);
                        $status_text->text(sprintf('Version %s is installed', $installed_version));
                        $status_text->color(cl::Black);
                    } else {
                        $status_text->text(sprintf('Cannot determine version of %s', $exe_file));
                        $status_text->color(cl::LightRed);
                    }
                } else {
                    $button_shortcuts->enabled(0);
                    $status_text->text('Installation path is not empty, but has no installed version, proceed with caution');
                    $status_text->color(cl::LightRed);
                }
            } else {
                # Can't check installed version on Linux
                    $button_shortcuts->enabled(0);
                    $status_text->text('Cannot test existing installation version on Linux, proceed with caution');
                    $status_text->color(cl::LightRed);
            }
        } else {
            $button_shortcuts->enabled(0);
            $status_text->text('Installation path is an existing file; cannot install');
            $status_text->color(cl::LightRed);
            return 0;
        }
    } else {
        $button_shortcuts->enabled(0);
        $status_text->text('Installation path is empty, ready for new installation');
        $status_text->color(cl::Black);
    }
    return 1;
}

sub install {
    my $self = shift;

    $button_install->enabled(0);
    $button_install->repaint();

    verify_install_dir($install_dir_text);

    if ($zip_file) {
        chomp($zip_file);
        if ($zip_file =~ m!gordonsreloadingtool\-\d+\.(\d+)\-.*?(zip|7z)$!msxi) {
            my $zip_version = $1;
            if ($zip_version == $installed_version) {
                $status_text->text(sprintf('Version %s is already installed', $installed_version));
                $status_text->color(cl::LightRed);
            } elsif ($zip_version < $installed_version) {
                $status_text->text(sprintf('Newer version (%s) is already installed', $installed_version));
                $status_text->color(cl::LightRed);
            } else {
                # Check if GRT is running
                my $pid;
                if ($is_Win and $pid = Win32::Process::List->new()->GetProcessPid('GordonsReloadingTool')) {
                    $status_text->text(sprintf('GordonsReloadingTool.exe is running (PID=%d), please exit the program first', $pid));
                    $status_text->color(cl::LightRed);
                    $button_install->enabled(1);
                    $button_install->repaint();
                } else {
                    # Check if installation dir is writable
                    unless (-d $install_dir) {
                        unless (eval { File::Path::make_path($install_dir) }) {
                            $status_text->text(sprintf('Cannot create the installation directory. Check permissions.'));
                            $status_text->color(cl::LightRed);
                            $button_install->enabled(1);
                            $button_install->repaint();
                            return 0;
                        }
                    }

                    my $is_zip = 1;
                    # Check for multi-part files
                    my $mp = substr($zip_file, 0, -2) . '01';
                    if (-e $mp) {
                        $status_text->text(sprintf('Assembling multi-part file...'));
                        $status_text->color(cl::Black);
                        my $temp_file = File::Temp->new(UNLINK => 0, SUFFIX => '.zip');
                        my @files;
                        foreach my $i (1 .. 9) {
                            $mp = substr($zip_file, 0, -2) . '0' . $i;
                            if (-e $mp) {
                                push @files, $mp;
                            } else {
                                last;
                            }
                        }
                        push @files, $zip_file;

                        foreach my $file (@files) {
                            if (open(my $F, '<', $file)) {
                                binmode $F;
                                my $buffer = '';
                                while (sysread($F, $buffer, $READ_BUFFER_LENGTH)) {
                                    print $temp_file $buffer;
                                }
                                close $F;
                            } else {
                                $status_text->text(sprintf('Cannot read file: %s (%s)', $file, $!));
                                $status_text->color(cl::LightRed);
                                $button_install->enabled(1);
                                $button_install->repaint();
                            }
                        }

                        $zip_file = $temp_file->filename;
                    }

                    if ($zip_file =~ m!\.7z$!msx) {
                        # Reassemble 7z file as ZIP. Could be optimized but 7z sucks and I don't want anything to do with it.
                        # It's a solution for a problem that shouldn't even exist.
                        undef $is_zip;
                        my $sz_command  = $is_Win ? File::Spec->catfile($ENV{'PAR_TEMP'} // '.', 'inc', 'contrib', '7z.exe') : '7z';
                        my $zip_command = $is_Win ? File::Spec->catfile($ENV{'PAR_TEMP'} // '.', 'inc', 'contrib', 'zip.exe') : 'zip';

                        # Extract to temporaty directory
                        my $tmp_dir = File::Temp->newdir(UNLINK => 0);
                        $status_text->text(sprintf('Extracting from 7z. No guarantees. 7z sucks. Use zip files instead.'));
                        system($sz_command, 'x', '-y', '-bb0', $zip_file, sprintf('-o%s', $tmp_dir), '-spe', '-aoa');

                        # On Win, it's impossible to unlink the open file, so use File::Temp to create a .zi file
                        # but use .zip instead
                        my $temp_file = File::Temp->new(UNLINK => 1, SUFFIX => '.zi');
                        my $temp_file_name = $temp_file->filename . 'p';

                        my $zip_params = join(' ', $zip_command, '-0rm', $temp_file_name, $tmp_dir);
                        system($zip_params);
                        $zip_file = $temp_file_name;
                    }

                    $status_text->text(sprintf('Reading installation file...'));
                    $status_text->color(cl::Black);
                    $status_text->repaint();

                    my $zip = Archive::Zip->new();
                    if ($zip->read($zip_file) == Archive::Zip::AZ_OK) {
                        my $root_id = $is_zip ? 0 : 1; # Created zip file has one extra member
                        my $root_dir = @{[$zip->members]}[$root_id]->fileName;

                        $status_text->text(sprintf('Installing... Please wait.'));
                        $status_text->color(cl::Green);
                        $status_text->repaint();

                        # Detect reports that need saving
                        my @report_files;
                        my $doku_dir = File::Spec->catfile($install_dir, 'doku');
                        if (-d $doku_dir) {
                            opendir my $DIR => $doku_dir;
                            my @lang_dirs = grep { -d $_ } map { File::Spec->catfile($doku_dir, $_) } grep { ! m!^\.!x } readdir $DIR;
                            closedir $DIR;

                            foreach my $dir (@lang_dirs) {
                                my $start_file = File::Spec->catfile($dir, 'report', 'start.txt');
                                push @report_files, substr($start_file, length($install_dir)) if -e $start_file; # Remove the install_dir part
                            }
                        }

                        # Save configuration files
                        foreach my $name (@configuration_files, @report_files) {
                            my $cfg = File::Spec->catfile($install_dir, $name);
                            my $cfg_bak = File::Spec->catfile($install_dir, $name . '.update.' . $installed_version);
                            if (-e $cfg) {
                                File::Copy::copy($cfg => $cfg_bak);
                            }
                        }

                        if ($zip->extractTree($root_dir => $install_dir) == Archive::Zip::AZ_OK) {

                            # Restrore configuration files
                            foreach my $name (@configuration_files, @report_files) {
                                my $cfg = File::Spec->catfile($install_dir, $name);
                                my $cfg_bak = File::Spec->catfile($install_dir, $name . '.update.' . $installed_version);
                                if (-e $cfg_bak) {
                                    File::Copy::move($cfg_bak => $cfg);
                                }
                            }

                            unless ($is_Win) {
                                # Fix permissions
                                chmod(0755 => File::Spec->catfile($install_dir, 'GordonsReloadingTool'));
                                chmod(0755 => File::Spec->catfile($install_dir, 'plugins/GRTLab/plugin-grtlab'));
                            }
                            $status_text->text(sprintf('Installation successful'));
                            unless ($is_zip) {
                                $status_text->text(sprintf('Extraction complete. No guarantees it worked. Use ZIP files for installation, 7z sucks.'));
                            }
                            $status_text->color(cl::Black);
                            $status_text->repaint();
                            $button_shortcuts->enabled(1);

                            $config->{_}->{'InstallDir'} = $install_dir;
                            save_config();
                            return 1;
                        } else {
                            $status_text->text(sprintf('Error while installing. Please try again.'));
                            $status_text->color(cl::LightRed);
                            $button_install->enabled(0);
                            return 0;
                        }
                    } else {
                        $status_text->text(sprintf('ZIP file error. Please select another file'));
                        $status_text->color(cl::LightRed);
                    }
                }
            }
        } else {
            $status_text->text('ZIP file does not look like a GRT installation file. Cannot proceed.');
            $status_text->color(cl::LightRed);
        }
    } else {
        $status_text->text('Select installation file');
        $status_text->color(cl::LightRed);
    }
    return 0;
}

sub create_shortcuts {
    my $self = shift;

    my $link = Win32::Shortcut->new();
    $link->{'Path'} = File::Spec->catfile($install_dir, 'GordonsReloadingTool.exe');
    $link->{'WorkingDirectory'} = $install_dir;
    $link->{'Description'} = 'GordonsReloadingTool';
    $link->Save(File::Spec->catfile($ENV{'USERPROFILE'}, 'Desktop', 'GordonsReloadingTool.lnk'));
    $link->Save(File::Spec->catfile($ENV{'APPDATA'}, 'Microsoft/Internet Explorer/Quick Launch', 'GordonsReloadingTool.lnk'));
    $link->Close();

    return 1;
}

sub guess_installation_file {
    my ($install_dir_text, $zip_file_text) = @_;

    my $download_dir = $config->{_}->{'DefaultOpenDir'};

    if (opendir my $DIR, $download_dir) {
        my @files = sort { lc $b cmp lc $a } grep { /^gordonsreloadingtool.*?\.(zip|7z)$/si } readdir $DIR;
        closedir $DIR;

        if (my $zip_file = shift @files) {
            $zip_file_text->text(File::Spec->catfile($download_dir, $zip_file));
            verify_zip_file($zip_file_text);
        }
    }
}
