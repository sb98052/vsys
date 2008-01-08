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
%define taglevel 2

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
cp vsys $RPM_BUILD_ROOT/usr/bin
cp vsys-initscript $RPM_BUILD_ROOT/etc/init.d/vsys

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/bin/vsys
/etc/init.d/vsys

%post
chkconfig --add vsys
chkconfig vsys on

%postun

%changelog
