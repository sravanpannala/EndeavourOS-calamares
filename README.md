
# EndeavourOS Calamares repository
**EndeavourOS specific calamares extra-modules, installer-scripts, branding and module configuration files**


[![Maintenance](https://img.shields.io/maintenance/yes/2022.svg)](https://github.com/endeavouros-team)

<img src="https://raw.githubusercontent.com/endeavouros-team/screenshots/master/Artemis/Artemis-Calamares.png" alt="calamares-welcome" width="600"/>

...

Calamares startup is handled by welcome (application) on EndeavourOS:

https://github.com/endeavouros-team/PKGBUILDS/tree/master/welcome

https://github.com/endeavouros-team/PKGBUILDS/blob/master/welcome/eos-install-mode-run-calamares


The config files in this repository are used by the following PKGBUILD's:

1. Calamares package itself:

https://github.com/endeavouros-team/PKGBUILDS/tree/master/calamares_current

2. EndeavourOS specific configurations for default installs:

https://github.com/endeavouros-team/PKGBUILDS/tree/master/calamares_config_default

3. Community Edition related configurations:

https://github.com/endeavouros-team/PKGBUILDS/tree/master/calamares_config_ce


**Changelog:**

* Main branch is now prepared for Calamares 3.3 changes (18 sept. 2022 joekamprad)

* New merged repository structure (october 2021) by joekamprad this repo now holds all needed files for the install process.
* Review and rewrite of custom modules (pacstrap e.t.c) for better integration into calamares and easier maintainment by dalto manuel and joekamprad (early 2022) 
* Build script cleanup and minimizations done by keybreak and joekamprad (April 2022)
