#
# Vsys filesystem
#
# RPM spec file
#
# $Id: vsys.spec,v 1.40 2007/04/03 02:08:55 mef Exp $
#

%define name vsys
%define version 0.4
%define release 2%{?pldistro:.%{pldistro}}%{?date:.%{date}}

Vendor: PlanetLab
Packager: PlanetLab Central <support@planet-lab.org>
Distribution: PlanetLab 4.0
URL: http://cvs.planet-lab.org/cvs/vsys

Summary: Vsys filesystem 
Name: %{name}
Version: %{version}
Release: %{release}
License: GPL
Group: System Environment/Kernel
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
#Requires: 

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
mkdir -p ${VSYS_INSTALL_DIR}/usr/bin
cp vsys ${VSYS_INSTALL_DIR}/usr/bin
cp vsys.b ${VSYS_INSTALL_DIR}/usr/bin
cp vsys-initscript ${VSYS_INSTALL_DIR}/etc/init.d/vsys
make -DVSYS_BIN_DIR=$RPM_BUILD_ROOT install

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
