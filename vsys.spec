#
# Vsys filesystem
#
# RPM spec file
#
# $Id$
#

%define url $URL$

%define name vsys
%define version 0.7
%define taglevel 14

%define release %{taglevel}%{?pldistro:.%{pldistro}}%{?date:.%{date}}

Vendor: PlanetLab
Packager: PlanetLab Central <support@planet-lab.org>
Distribution: PlanetLab %{plrelease}
URL: %(echo %{url} | cut -d ' ' -f 2)

Summary: Vsys filesystem 
Name: %{name}
Version: %{version}
Release: %{release}
License: GPL
Group: System Environment/Kernel
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
#Requires: 
BuildRequires: inotify-tools-devel
BuildRequires: ocaml
BuildRequires: ocaml-docs

Source0: vsys-%{version}.tar.gz

%description
vsys is a file-system-based interface that lets slices on PlanetLab safely
invoke services installed by the PlanetLab administration. Slices invoke and
interact with these services through fifo pipes. Services can be added and
removed dynamically.

%prep
%setup

%build
rm -rf $RPM_BUILD_ROOT
make

%install
mkdir -p $RPM_BUILD_ROOT/usr/bin
mkdir -p $RPM_BUILD_ROOT/etc/init.d
mkdir -p $RPM_BUILD_ROOT/vsys
cp factory/* $RPM_BUILD_ROOT/vsys
cp vsys $RPM_BUILD_ROOT/usr/bin
cp vsys-initscript $RPM_BUILD_ROOT/etc/init.d/vsys
cp vsys.conf $RPM_BUILD_ROOT/etc

install -D -m 644 vsys.logrotate $RPM_BUILD_ROOT/%{_sysconfdir}/logrotate.d/vsys

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/bin/vsys
/etc/init.d/vsys
/vsys/*
%config(noreplace) /etc/vsys.conf
%{_sysconfdir}/logrotate.d/vsys

%post
chkconfig --add vsys
chkconfig vsys on

%postun

%changelog
* Mon Jun 23 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-14
- This change is an attempt to fix unexpected blocking after many days of uptime, reported by KyoungSoo.

* Thu Jun 19 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-13
- accept '-' in filenames also
- 

* Wed Jun 18 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-12
- don't overwrite the config file that already exists.
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-11
- Suppress some temp file that RPM creates frmo showing up as a vsys script.
- 
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-10
- Changed a policy in vsys. When an acl is empty, the script doesn't show up in ANY slice. The previous behavior was for 
- it to show up in all slices.
- 
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-9
- Added a vsys script for CoMon.
- 

* Mon Jun 16 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-8
- ignore non-existent directories after restart.
- 

* Fri May 16 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-7
- added logrotate configuration to package.
- 

* Mon May 12 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-6
- Added two new scripts for CoMon on 4.2
- 

* Tue May 06 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-5
- 
- Corrected directory that the script mounts to the correct one:
- /var/local/fprobe
- 

* Wed Apr 23 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-4
- Pulling the latest changes for the 4.2rc2 release
- 

* Fri Feb 15 2008 Faiyaz Ahmed <faiyaza@cs.princeton.edu> - vsys-0.7-2 vsys-0.7-3
- * daemonization, writing to a logfile, and saving the pid
- 

