#!/bin/bash

# Made by fernandomaroto for EndeavourOS and Portergos
# Adapted from AIS. An excellent bit of code!
# ISO-NEXT specific cleanup removals and additions (08-2021) @killajoe and @manuel

if [ -f /tmp/chrootpath.txt ]
then 
    chroot_path=$(cat /tmp/chrootpath.txt |sed 's/\/tmp\///')
else 
    chroot_path=$(lsblk |grep "calamares-root" |awk '{ print $NF }' |sed -e 's/\/tmp\///' -e 's/\/.*$//' |tail -n1)
fi

if [ -z "$chroot_path" ] ; then
    echo "Fatal error: cleaner_script.sh: chroot_path is empty!"
fi

if [ -f /tmp/new_username.txt ]
then
    NEW_USER=$(cat /tmp/new_username.txt)
else
    #NEW_USER=$(compgen -u |tail -n -1)
    NEW_USER=$(cat /tmp/$chroot_path/etc/passwd | grep "/home" |cut -d: -f1 |head -1)
fi

arch_chroot(){
# Use chroot not arch-chroot because of the way calamares mounts partitions
    chroot /tmp/$chroot_path /bin/bash -c "${1}"
}  

# Anything to be executed outside chroot need to be here.

# Copy any file from live environment to new system

cp -f /etc/skel/.bashrc /tmp/$chroot_path/home/$NEW_USER/.bashrc
cp -f /etc/environment /tmp/$chroot_path/etc/environment
#cp -rf /home/liveuser/.gnupg/gpg.conf /tmp/$chroot_path/etc/pacman.d/gnupg/gpg.conf

_CopyFileToTarget() {
    # Copy a file to target

    local file="$1"
    local targetdir="$2"

    if [ ! -r "$file" ] ; then
        echo "====> warning: file '$file' does not exist."
        return
    fi
    if [ ! -d "$targetdir" ] ; then
        echo "====> warning: folder '$targetdir' does not exist."
        return
    fi
    echo "====> copying $(basename "$file") to target"
    cp "$file" "$targetdir"
}

_copy_files(){
    local config_file
    local target=/tmp/$chroot_path            # $target refers to the / folder of the installed system

    if [ -x $target/usr/bin/sddm ] ; then
        # This is for online install only, because offline install is set to use lightdm.

        echo "====> Copying DM config file $config_file to target"

        config_file=/etc/sddm.conf.d/kde_settings.conf
        mkdir -p $target$(dirname $config_file)
        cp /etc/calamares/files/sddm.conf.d/kde_settings.conf $target$config_file
    fi

    if [ -x $target/usr/bin/lightdm ] ; then        
        echo "====> Copying DM config file $config_file to target"

        config_file=/etc/lightdm/slick-greeter.conf
        rsync -vaRI $config_file $target
    fi

    if [ -r /home/liveuser/setup.url ] ; then
        # Is this needed anymore?
        # /home/liveuser/setup.url contains the URL to personal setup.sh
        local URL="$(cat /home/liveuser/setup.url)"
        if (wget -q -O /home/liveuser/setup.sh "$URL") ; then
            echo "====> Copying setup.sh to target"
            cp /home/liveuser/setup.sh $target/tmp/   # into /tmp/setup.sh of chrooted
        fi
    fi

    # Communicate to chrooted system if
    # - nvidia card is detected
    # - livesession is running nvidia driver

    local nvidia_file=$target/tmp/nvidia-info.bash
    local card=no
    local driver=no
    local lspci="$(lspci -k)"

    if [ -n "$(echo "$lspci" | grep -P 'VGA|3D|Display' | grep -w NVIDIA)" ] ; then
        card=yes
        [ -n "$(lsmod | grep -w nvidia)" ]                                                   && driver=yes
        [ -n "$(echo "$lspci" | grep -wA2 NVIDIA | grep "Kernel driver in use: nvidia")" ]   && driver=yes
        if [ "$driver" = "yes" ] ; then
            echo "====> info: using nvidia driver"
        else
            echo "====> info: using nouveau driver"
        fi
    fi
    echo "nvidia_card=$card"     >> $nvidia_file
    echo "nvidia_driver=$driver" >> $nvidia_file

    # copy user_commands.bash
    _CopyFileToTarget /home/liveuser/user_commands.bash $target/tmp

    # copy 30-touchpad.conf Xorg config file
    echo "====> Copying 30-touchpad.conf to target"
    mkdir -p $target/usr/share/X11/xorg.conf.d
    cp /usr/share/X11/xorg.conf.d/30-touchpad.conf  $target/usr/share/X11/xorg.conf.d/

    # copy endeavouros-release file
    local file=/usr/lib/endeavouros-release
    if [ -r $file ] ; then
        if [ ! -r $target$file ] ; then
            echo "====> Copying $file to target"
            rsync -vaRI $file $target
        fi
    else
        echo "==> $FUNCNAME: error: file $file does not exist in the ISO, copy to target failed!"
    fi
}

_copy_files
