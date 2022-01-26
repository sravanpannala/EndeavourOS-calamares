#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import shutil

import libcalamares
from libcalamares.utils import *


def run():
    """ Copy kernel and install scripts to target system.

    :return:
    """

    kernel_path = "/run/archiso/bootmnt/arch/boot/x86_64/"
    kernel_root = "vmlinuz"

    root_mount_point = libcalamares.globalstorage.value("rootMountPoint")
    if not root_mount_point:
        return ("No mount point for root partition in globalstorage",
                "globalstorage does not contain a \"rootMountPoint\" key, "
                "doing nothing")

    if not os.path.exists(root_mount_point):
        return ("Bad mount point for root partition in globalstorage",
                "globalstorage[\"rootMountPoint\"] is \"{}\", which does not "
                "exist, doing nothing".format(root_mount_point))

    try:
        # Copy any kernels
        for file in os.listdir(kernel_path):
            if file.strip(kernel_root):
                shutil.copy2(file, os.path.join(root_mount_point, "boot", os.path.basename(file)))

        # Copy cleaner script
        source = "/etc/calamares/scripts/chrooted_cleaner_script.sh"
        dest = os.path.join(root_mount_point + "etc/calamares/scripts" + "chrooted_cleaner_script.sh")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(source, dest)
    except Exception as e:
        return "File copy failed", "kernel-copy failed to copy file with error " + format(e)

    return None
