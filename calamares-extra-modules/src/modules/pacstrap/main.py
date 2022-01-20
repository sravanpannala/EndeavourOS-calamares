#!/usr/bin/env python3

import os
import subprocess
import shutil

import libcalamares
from libcalamares.utils import gettext_path, gettext_languages

import gettext

_translation = gettext.translation("calamares-python",
                                   localedir=gettext_path(),
                                   languages=gettext_languages(),
                                   fallback=True)
_ = _translation.gettext
_n = _translation.ngettext

custom_status_message = None


def pretty_name():
    return _("Install base system")


def pretty_status_message():
    if custom_status_message is not None:
        return custom_status_message


def line_cb(line):
    global custom_status_message
    custom_status_message = line.strip()
    libcalamares.utils.debug(line)


def run():
    """
    Installs the base system packages and copies files post-installation

    """
    root_mount_point = libcalamares.globalstorage.value("rootMountPoint")

    if not root_mount_point:
        return ("No mount point for root partition in globalstorage",
                "globalstorage does not contain a \"rootMountPoint\" key, "
                "doing nothing")

    if not os.path.exists(root_mount_point):
        return ("Bad mount point for root partition in globalstorage",
                "globalstorage[\"rootMountPoint\"] is \"{}\", which does not "
                "exist, doing nothing".format(root_mount_point))

    if libcalamares.job.configuration:
        if "basePackages" in libcalamares.job.configuration:
            base_packages = libcalamares.job.configuration["basePackages"]
        else:
            return "Package List Missing", "Cannot continue without list of packages to install"
    else:
        return "No configuration found", "Aborting due to missing configuration"

    # run the pacstrap
    package_list = " ".join(base_packages)
    pacstrap_command = ["/etc/calamares/scripts/pacstrap_calamares", "-c", package_list]

    try:
        libcalamares.utils.host_env_process_output(pacstrap_command, line_cb)
    except subprocess.CalledProcessError as cpe:
        return "Failed to run pacstrap", "Pacstrap failed with error {!s}".format(cpe.output)

    # copy files post install
    if "postInstallFiles" in libcalamares.job.configuration:
        files_to_copy = libcalamares.job.configuration["postInstallFiles"]
        for source_file in files_to_copy:
            if os.path.exists(source_file):
                try:
                    libcalamares.utils.debug("Copying file {!s}".format(source_file))
                    shutil.copy2(source_file, os.path.join(root_mount_point, source_file))
                except Exception as e:
                    libcalamares.utils.warning("Failed to copy file {!s}, error {!s}".format(source_file, e))

    return None
