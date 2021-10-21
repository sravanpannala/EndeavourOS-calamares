#!/bin/bash

# New version of cleaner_script
# Made by @fernandomaroto and @manuel 
# Any failed command will just be skipped, error message may pop up but won't crash the install process
# Net-install creates the file /tmp/run_once in live environment (need to be transfered to installed system) so it can be used to detect install option
# ISO-NEXT specific cleanup removals and additions (08-2021) @killajoe and @manuel

if [ -f /tmp/new_username.txt ]
then
    NEW_USER=$(cat /tmp/new_username.txt)
else
    #NEW_USER=$(compgen -u |tail -n -1)
    NEW_USER=$(cat /tmp/$chroot_path/etc/passwd | grep "/home" |cut -d: -f1 |head -1)
fi

_check_internet_connection(){
    #ping -c 1 8.8.8.8 >& /dev/null   # ping Google's address
    curl --silent --connect-timeout 8 https://8.8.8.8 > /dev/null
}

_is_pkg_installed() {
    # returns 0 if given package name is installed, otherwise 1
    local pkgname="$1"
    pacman -Q "$pkgname" >& /dev/null
}

_remove_a_pkg() {
    local pkgname="$1"
    pacman -Rsn --noconfirm "$pkgname"
}

_remove_pkgs_if_installed() {
    # removes given package(s) and possible dependencies if the package(s) are currently installed
    local pkgname
    for pkgname in "$@" ; do
        _is_pkg_installed "$pkgname" && _remove_a_pkg "$pkgname"
    done
}

_vbox(){
    local vbox_guest_packages=(
        virtualbox-guest-utils
        # xf86-video-vmware       # a dependency of virtualbox-guest-utils
    )

    case "$(device-info --vm)" in           # 2021-Sep-30: device-info may output one of: "virtualbox", "qemu", "kvm", "vmware" or ""
        virtualbox)
            # If using net-install detect VBox and install the packages
            if [ -f /tmp/run_once ] ; then
                pacman -S --needed --noconfirm "${vbox_guest_packages[@]}"
            fi
            ;;
        *)
            local pkg
            for pkg in "${vbox_guest_packages[@]}" ; do
                _is_pkg_installed "$pkg" && pacman -Rnsdd "$pkg" --noconfirm
            done
            #rm -f /usr/lib/modules-load.d/virtualbox-guest-dkms.conf   # not needed anymore?
            ;;
    esac
}

_vmware() {
    local vmware_guest_packages=(
        open-vm-tools
        xf86-input-vmmouse
        xf86-video-vmware           # note: virtualbox-guest uses this
    )
    local vmname="$(device-info --vm)"

    case "$vmname" in
        vmware)
            pacman -S --needed --noconfirm "${vmware_guest_packages[@]}"
            ;;
        *)
            local pkg
            for pkg in "${vmware_guest_packages[@]}" ; do
                if [ "$pkg" = "xf86-video-vmware" ] && [ "$vmname" = "virtualbox" ] ; then
                    continue                                                                 # virtualbox needs this package!
                fi
                _is_pkg_installed "$pkg" && pacman -Rns "$pkg" --noconfirm
            done
            ;;
    esac
}

_qemu() {
    local qemu_packages=(
        qemu-guest-agent
    )
    case "$(device-info --vm)" in
        qemu)                        # and 'kvm' ??
            pacman -S --needed --noconfirm "${qemu_packages[@]}"
            ;;
        *)
            local pkg
            for pkg in "${qemu_packages[@]}" ; do
                _is_pkg_installed "$pkg" && pacman -Rnsdd "$pkg" --noconfirm
            done
            ;;
    esac
}

_sed_stuff(){

    # Journal for offline. Turn volatile (for iso) into a real system.
    sed -i 's/volatile/auto/g' /etc/systemd/journald.conf 2>>/tmp/.errlog
    sed -i 's/.*pam_wheel\.so/#&/' /etc/pam.d/su
}

_os_lsb_release(){

    # Check if offline is still copying the files, sed is the way to go!
    # same as os-release hook
    sed -i -e s'|^NAME=.*$|NAME=\"EndeavourOS\"|' -e s'|^PRETTY_NAME=.*$|PRETTY_NAME=\"EndeavourOS\"|' -e s'|^HOME_URL=.*$|HOME_URL=\"https://endeavouros.com\"|' -e s'|^DOCUMENTATION_URL=.*$|DOCUMENTATION_URL=\"https://endeavouros.com/wiki/\"|' -e s'|^SUPPORT_URL=.*$|SUPPORT_URL=\"https://forum.endeavouros.com\"|' -e s'|^BUG_REPORT_URL=.*$|BUG_REPORT_URL=\"https://github.com/endeavouros-team\"|' -e s'|^LOGO=.*$|LOGO=endeavouros|' /usr/lib/os-release

    # same as lsb-release hook
    sed -i -e s'|^DISTRIB_ID=.*$|DISTRIB_ID=EndeavourOS|' -e s'|^DISTRIB_DESCRIPTION=.*$|DISTRIB_DESCRIPTION=\"EndeavourOS Linux\"|' /etc/lsb-release

}

_clean_archiso(){

    local _files_to_remove=(                               
        /etc/sudoers.d/g_wheel
        /etc/ssh/sshd_config
        /var/lib/NetworkManager/NetworkManager.state
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
        /etc/systemd/system/getty@tty1.service.d
        /etc/systemd/system/multi-user.target.wants/*
        /etc/systemd/journald.conf.d
        /etc/systemd/logind.conf.d
        /etc/mkinitcpio-archiso.conf
        /etc/initcpio
        /home/$NEW_USER/{.xinitrc,.xsession,.xprofile,.wget-hsts,.screenrc,.ICEauthority}
        /root/{.automated_script.sh,.zlogin,.xinitrc,.xsession,.xprofile,.wget-hsts,.screenrc,.ICEauthority}
        /root/.config/{qt5ct,Kvantum,dconf}
        /etc/motd
        /{gpg.conf,gpg-agent.conf,pubring.gpg,secring.gpg}
        /version
    )

    local xx

    for xx in ${_files_to_remove[*]}; do rm -rf $xx; done

    find /usr/lib/initcpio -name archiso* -type f -exec rm '{}' \;

}

_clean_offline_packages(){

    local _packages_to_remove=( 
    gparted
    grsync
    calamares_current
    calamares_config_default
    calamares_config_ce
    edk2-shell
    boost-libs
    doxygen
    expect
    gpart
    tcpdump
    libpwquality
    refind
    rate-mirrors-bin
    kvantum-qt5
    polkit-qt5
    qca-qt5
    qt5-location
    qt5-multimedia
    qt5-speech
    qt5-wayland
    qt5-webchannel
    qt5-webengine
    qt5-xmlpatterns
    qt5-base
    sonnet
    kwidgetsaddons
    kitemviews
    kguiaddons
    kdbusaddons
    kcoreaddons
    karchive
    qt5ct
    arch-install-scripts
    squashfs-tools
    extra-cmake-modules 
    cmake
    elinks
    yaml-cpp
    syslinux
    clonezilla
    ckbcomp
    xcompmgr
    memtest86+
    mkinitcpio-archiso
)
    local xx
    # @ does one by one to avoid errors in the entire process
    # * can be used to treat all packages in one command
    for xx in ${_packages_to_remove[@]}; do pacman -Rsc $xx --noconfirm; done

}

_endeavouros(){


    [ -r /root/.bash_profile ] && sed -i "/if/,/fi/"'s/^/#/' /root/.bash_profile
    sed -i "/if/,/fi/"'s/^/#/' /home/$NEW_USER/.bash_profile

}

_fix_offline_mirrorlist() {
    # For offline install only!
    # If a mirrorlist could not be generated because of no connection, use the following.

    /usr/bin/cat <<EOF > /etc/pacman.d/mirrorlist
### This mirrorlist was written during install at $(date -u +%Y-%m-%d).
###
### Note that the mirrors were not ranked, so you may get better mirrorlist
### by ranking with e.g. program 'reflector-simple'.

## Germany
Server = http://mirror.f4st.host/archlinux/\$repo/os/\$arch
Server = https://mirror.f4st.host/archlinux/\$repo/os/\$arch

## United States
Server = http://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch

## Germany
Server = https://mirror.pseudoform.org/\$repo/os/\$arch

## United States
Server = http://mirror.lty.me/archlinux/\$repo/os/\$arch
Server = https://mirror.lty.me/archlinux/\$repo/os/\$arch
EOF
}


_check_install_mode(){

    if [ -f /tmp/run_once ] ; then
        local INSTALL_OPTION="ONLINE_MODE"
    else
        local INSTALL_OPTION="OFFLINE_MODE"
    fi

    case "$INSTALL_OPTION" in
        OFFLINE_MODE)
                _clean_archiso
                chown $NEW_USER:$NEW_USER /home/$NEW_USER/.bashrc
                _sed_stuff
                _clean_offline_packages
                # _check_internet_connection && _fix_offline_mirrorlist
                # _check_internet_connection && update-mirrorlist
            ;;

        ONLINE_MODE)
                # not implemented yet. For now run functions at "SCRIPT STARTS HERE"
                :
                # all systemd are enabled - can be specific offline/online in the future
            ;;
        *)
            ;;
    esac
}

_remove_ucode(){
    local ucode="$1"
    pacman -Q $ucode >& /dev/null && {
        pacman -Rsn $ucode --noconfirm >/dev/null
    }
}

_remove_other_graphics_drivers() {
    local graphics="$(device-info --vga ; device-info --display)"
    local amd=no

    # remove Intel graphics driver if it is not needed
    if [ -z "$(echo "$graphics" | grep "Intel Corporation")" ] ; then
        _remove_pkgs_if_installed xf86-video-intel
    fi

    # remove AMD graphics driver if it is not needed
    if [ -n "$(echo "$graphics" | grep "Advanced Micro Devices")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "AMD/ATI")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "Radeon")" ] ; then
        amd=yes
    fi
    if [ "$amd" = "no" ] ; then
        _remove_pkgs_if_installed xf86-video-amdgpu xf86-video-ati
    fi
}

_remove_broadcom_wifi_driver() {
    local pkgname=broadcom-wl-dkms
    local wifi_pci
    local wifi_driver

    _is_pkg_installed $pkgname && {
        wifi_pci="$(lspci -k | grep -A4 " Network controller: ")"
        if [ -n "$(lsusb | grep " Broadcom ")" ] || [ -n "$(echo "$wifi_pci" | grep " Broadcom ")" ] ; then
            return
        fi
        wifi_driver="$(echo "$wifi_pci" | grep "Kernel driver in use")"
        if [ -n "$(echo "$wifi_driver" | grep "in use: wl$")" ] ; then
            return
        fi
        _remove_a_pkg $pkgname
    }
}

_manage_nvidia_packages() {
    local file=/tmp/nvidia-info.bash        # nvidia info from livesession
    local nvidia_card=""                    # these two variables are defined in $file
    local nvidia_driver=""

    if [ ! -r $file ] ; then
        echo "==> Warning: file $file does not exist!"

        if [ 1 -eq 1 ] ; then       # this line: change first 1 to 0 when old code is not needed
            echo "==> Info: running the old nvidia mgmt code instead."
            if [ -z "$(lspci -k | grep -P 'VGA|3D|Display' | grep -w NVIDIA)" ] || [ -z "$(lspci -k | grep -B2 "Kernel driver in use: nvidia" | grep -P 'VGA|3D|Display')" ] ; then
                local xx="$(pacman -Qqs nvidia* | grep ^nvidia)"
                test -n "$xx" && pacman -Rsn $xx --noconfirm
            fi
        fi
        return
    fi

    source $file

    case "$nvidia_card" in
        yes)
            local install=(nvidia-installer-dkms)
            [ "$nvidia_driver" = "yes" ] && install+=(nvidia-dkms)
            pacman -S --needed --noconfirm "${install[@]}"
            ;;
        no)
            local remove="$(pacman -Qqs nvidia* | grep ^nvidia)"
            [ "$remove" != "" ] && pacman -Rsn --noconfirm $remove
            ;;
    esac
}

_run_if_exists_or_complain() {
    local app="$1"

    if (which "$app" >& /dev/null) ; then
        echo "==> Info: running $*"
        "$@"
    else
        echo "==> Warning: program $app not found."
    fi
}

_fix_grub_stuff() {
    _run_if_exists_or_complain eos-hooks-runner
    _run_if_exists_or_complain eos-grub-fix-initrd-generation
}

_RunUserCommands() {
    local usercmdfile=/tmp/user_commands.bash
    if [ -r $usercmdfile ] ; then
        echo "==> running $(basename $usercmdfile)"
        bash $usercmdfile
    fi
}

_clean_up(){
    local xx

    # Remove the "wrong" microcode.
    if [ -x /usr/bin/device-info ] ; then
        case "$(/usr/bin/device-info --cpu)" in
            GenuineIntel) _remove_ucode amd-ucode ;;
            *)            _remove_ucode intel-ucode ;;
        esac
    fi

    # Fix various grub stuff.
    _fix_grub_stuff

    # install or remove nvidia graphics stuff
    _manage_nvidia_packages

    # remove AMD and Intel graphics drivers if they are not needed
    _remove_other_graphics_drivers

    # remove broadcom-wl-dkms if it is not needed
    _remove_broadcom_wifi_driver

    # keep r8168 package but blacklist it; r8169 will be used by default
    xx=/usr/lib/modprobe.d/r8168.conf
    test -r $xx && sed -i $xx -e 's|r8169|r8168|'

    # if both Xfce and i3 are installed, remove dex package
    if [ -r /usr/share/xsessions/xfce.desktop ] && [ -r /usr/share/xsessions/i3.desktop ] ; then
        _remove_pkgs_if_installed dex
    fi

    # run possible user-given commands
    _RunUserCommands
}

_desktop_i3(){
    # i3 configs here
    # Note: variable 'desktop' from '_another_case' is visible here too!

    if ! _check_internet_connection ; then
        echo "==> Cannot fetch i3 configs, no connection."
        return
    fi

    git clone $(eos-github2gitlab https://github.com/endeavouros-team/endeavouros-i3wm-setup.git)
    pushd endeavouros-i3wm-setup >/dev/null
    cp -R .config ~/
    cp -R .config /home/$NEW_USER/                                                
    chmod -R +x ~/.config/i3/scripts /home/$NEW_USER/.config/i3/scripts
    cp set_once.sh  ~/
    cp set_once.sh  /home/$NEW_USER/
    chmod +x ~/set_once.sh /home/$NEW_USER/set_once.sh
    cp .Xresources ~/
    cp .Xresources /home/$NEW_USER/
    cp .gtkrc-2.0 ~/
    cp .gtkrc-2.0 /home/$NEW_USER/
    cp .nanorc ~/
    cp .nanorc /home/$NEW_USER/
    cp xed.dconf ~/
    cp xed.dconf /home/$NEW_USER/
    cp .bashrc ~/
    cp .bashrc /home/$NEW_USER/
    cp .bash_profile ~/
    cp .bash_profile /home/$NEW_USER/
    chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/
    popd >/dev/null
    rm -rf endeavouros-i3wm-setup
}

_de_wm_config(){
    local desktops_lowercase="$(ls -1 /usr/share/xsessions/*.desktop | tr '[:upper:]' '[:lower:]' | sed -e 's|\.desktop$||' -e 's|^/usr/share/xsessions/||')"
    local desktop
    local i3_added=no # break for loop

    for desktop in $desktops_lowercase ; do
        case "$desktop" in
            i3*)
                if [ "$i3_added" = "no" ] ; then
                    i3_added=yes
                    _desktop_i3 
                fi
                ;;
        esac
    done
}

_setup_personal() {
    local file=/tmp/setup.sh
    local tmpdir
    if [ -r $file ] ; then
        # setup.sh was found, so run it
        tmpdir=$(mktemp -d)     # $tmpdir refers to a unique folder under /tmp
        pushd $tmpdir >/dev/null
        sh $file
        popd >/dev/null
        rm -rf $tmpdir
    else
        echo "Info: $FUNCNAME: $file not found." >&2
    fi
}

_change_config_options(){
    #set lightdm.conf to logind-check-graphical=true
    sed -i 's?#logind-check-graphical=false?logind-check-graphical=true?' /etc/lightdm/lightdm.conf
    sed -i 's?#greeter-session=example-gtk-gnome?greeter-session=lightdm-slick-greeter?' /etc/lightdm/lightdm.conf
    sed -i 's?#allow-user-switching=true?allow-user-switching=true?' /etc/lightdm/lightdm.conf
}

_remove_gnome_software(){
    pacman -Rsn --noconfirm gnome-software
}
_remove_discover(){
    pacman -Rsn --noconfirm discover
}

_run_hotfix_end() {
    local file=hotfix-end.bash
    if ! _check_internet_connection ; then
        echo "==> Cannot fetch $file, no connection."
        return
    fi
    local url=$(eos-github2gitlab https://raw.githubusercontent.com/endeavouros-team/ISO-hotfixes/main/$file)
    wget --timeout=60 -q -O /tmp/$file $url && {
        bash /tmp/$file
    }
}

########################################
########## SCRIPT STARTS HERE ##########
########################################

_check_install_mode
_endeavouros
#_os_lsb_release
_vmware
_vbox
_qemu
_change_config_options
#_remove_gnome_software
#_remove_discover
_de_wm_config
#_setup_personal
_clean_up
_run_hotfix_end

rm -R /etc/calamares
