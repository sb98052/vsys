#
# Vsys filesystem
#
# RPM spec file
#
# $Id$
#

%define url $URL$

%define name vsys
%define version 0.95
%define taglevel 0

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
#cp factory/* $RPM_BUILD_ROOT/vsys
cp vsys $RPM_BUILD_ROOT/usr/bin
cp vsys-initscript $RPM_BUILD_ROOT/etc/init.d/vsys
cp vsys.conf $RPM_BUILD_ROOT/etc

install -D -m 644 vsys.logrotate $RPM_BUILD_ROOT/%{_sysconfdir}/logrotate.d/vsys

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/bin/vsys
/etc/init.d/vsys
/vsys
%config(noreplace) /etc/vsys.conf
%{_sysconfdir}/logrotate.d/vsys

%post
chkconfig --add vsys
chkconfig vsys on
if [ "$PL_BOOTCD" != "1" ] ; then
        service vsys restart
fi

%postun

%changelog
* Tue Feb 24 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-26
- Tagging to force an update.

* Fri Feb 20 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-25

* Fri Feb 20 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-24

* Thu Feb 19 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-23

* Tue Sep 30 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-22
- Tagging a trivial fix.

* Thu Sep 25 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-21
- includes new portsummary script for CoMon

* Mon Aug 11 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-20
- trying to fix the taglevel relative to the branch name

* Thu Jul 17 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-18
- Change for someone at Imperial.ac.uk, who wants access to Netflow data.

* Tue Jul 15 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-17
- * Don't kill vsys twice on restarts, do it only once
- * Restart vsys following a reinstall

* Wed Jul 02 2008 Thierry Parmentelat <thierry.parmentelat@sophia.inria.fr> - vsys-0.7-16
- Usability changes that are necessary for the stability of CoMon

* Wed Jun 25 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-15
- added patch to pl-ps needed by slicestat
- 
- 

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

