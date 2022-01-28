#!/usr/bin/env python3

import os


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
    return _(libcalamares.job.configuration.get("name", "Loading user configured packages"))


def get_netinstall_data(packages):
    return {"source": "userPkgList", "name": libcalamares.job.configuration.get("netinstall_name", "Custom Packages"),
            "description": libcalamares.job.configuration.get("netinstall_desc", "The custom packagelist defined"),
            "hidden": False, "selected": True, "critical": True, "packages": packages}


def run():
    # Get the file location from the configuration file
    file_location = libcalamares.job.configuration.get("file_location", None)
    if file_location and os.path.exists(file_location):
        packages = []
        # Read the file and consider each line a packagename
        with open(file_location) as packages_file:
            for line in packages_file:
                if line.strip():
                    packages.append(line.strip())

        # Turn the packages list into a structure suitable for netinstall and load it into global storage
        if packages:
            netinstall_data = [get_netinstall_data(packages)]

            # check and see if netinstallAdd data is already in global storage.  If it is, combine them
            if libcalamares.globalstorage.contains("netinstallAdd"):
                netinstall_data = libcalamares.globalstorage.value("netinstallAdd") + netinstall_data
            libcalamares.globalstorage.insert("netinstallAdd", netinstall_data)

    return None
