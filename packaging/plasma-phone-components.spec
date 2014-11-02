# 
# Do NOT Edit the Auto-generated Part!
# Generated by: spectacle version 0.27
# 

Name:       plasma-phone-components

# >> macros
# << macros

Summary:    Plasma Phone Components
Version:    0.1.0
Release:    1
Group:      System/GUI/Other
License:    GPLv2+
URL:        http://www.kde.org
Source0:    %{name}-%{version}.tar.xz
Source100:  plasma-phone-components.yaml
Requires:   greenisland
Requires:   plasma-workspace
Requires:   plasma-workspace-wallpaper-image
Requires:   breeze-icon-theme
Requires:   oxygen-fonts
Requires:   frameworkintegration
Requires:   libqofono-qt5
Requires:   libqofono-qt5-declarative
Requires:   voicecall-qt5
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Xml)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(Qt5Widgets)
BuildRequires:  pkgconfig(Qt5Test)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  extra-cmake-modules
BuildRequires:  kf5-rpm-macros
BuildRequires:  qt5-tools
BuildRequires:  plasma-devel

%description
Plasma Phone Components.


%prep
%setup -q -n %{name}-%{version}

# >> setup
# << setup

%build
# >> build pre
%kf5_make
# << build pre



# >> build post
# << build post

%install
rm -rf %{buildroot}
# >> install pre
%kf5_make_install
# << install pre

# >> install post

# Script that runs the UI
# File with environment variables, used by compositor systemd unit
mkdir -p %{buildroot}%{_sharedstatedir}/environment/greenisland
cat > %{buildroot}%{_sharedstatedir}/environment/greenisland/greenisland.conf <<EOF
# Use QScreen backend
KSCREEN_BACKEND=QScreen

# This one is often set to 1 but, at least for hammerhead, we need it set to 0
# TODO: Check whether this is always the case when we'll support more devices
QT_COMPOSITOR_NEGATE_INVERTED_Y=0
EOF

# File with environment variables, used by shell systemd unit
mkdir -p %{buildroot}%{_sharedstatedir}/environment/plasma-phone
cat > %{buildroot}%{_sharedstatedir}/environment/plasma-phone/plasma-phone.conf <<EOF
LIBEXEC_PATH="%{_libexecdir}:%{_libdir}/libexec:%{_kf5_libexecdir}"
QT_PLUGIN_PATH=\${QT_PLUGIN_PATH+\$QT_PLUGIN_PATH:}\`qtpaths --plugin-dir\`:%{_libdir}/kde5/plugins

DBUS_SESSION_BUS_ADDRESS=unix:path=%t/dbus/user_bus_socket

QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=KDE
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
XDG_CURRENT_DESKTOP=KDE
KSCREEN_BACKEND=QScreen

KDE_FULL_SESSION=1
KDE_SESSION_VERSION=5
EOF

# Default configuration for the UI
mkdir -p %{buildroot}%{_kf5_configdir}
cat > %{buildroot}%{_kf5_configdir}/kded5rc << EOF
[General]
CheckSycoca=false
EOF

cat > %{buildroot}%{_kf5_configdir}/kdeglobals <<EOF
[KDE]
LookAndFeelPackage=org.kde.satellite.phone

[General]
desktopFont=Oxygen Sans,9,-1,5,50,0,0,0,0,0
fixed=Oxygen Mono,8,-1,5,50,0,0,0,0,0
font=Oxygen Sans,9,-1,5,50,0,0,0,0,0
menuFont=Oxygen Sans,9,-1,5,50,0,0,0,0,0
smallestReadableFont=Oxygen Sans,7,-1,5,50,0,0,0,0,0
taskbarFont=Oxygen Sans,9,-1,5,50,0,0,0,0,0
toolBarFont=Oxygen Sans,8,-1,5,50,0,0,0,0,0

[Icons]
Theme=breeze

[Theme]
name=default
EOF

# Install services links
mkdir -p %{buildroot}%{_libdir}/systemd/user/user-session.target.wants
UNITS="plasma-phone-compositor plasma-phone-ui"
for service in $UNITS; do
ln -sf ../${service}.service %{buildroot}%{_libdir}/systemd/user/user-session.target.wants/${service}.service
done
# << install post

%files
%defattr(-,root,root,-)
%config %{_kf5_configdir}/kdeglobals
%config %{_kf5_configdir}/kded5rc
%{_bindir}/plasma-phone
%{_kf5_sharedir}/plasma/*
%{_kf5_sharedir}/wallpapers/*
%{_kf5_servicesdir}/*.desktop
%{_sharedstatedir}/environment/greenisland/*
%{_sharedstatedir}/environment/plasma-phone/*
%{_libdir}/systemd/user/*
%{_libdir}/systemd/user/user-session.target.wants/*
%{_libdir}/qt5/qml/*
# >> files
# << files
