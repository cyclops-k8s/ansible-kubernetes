# Purpose
This will install the crun runtime to replace runc which is used by default.

# Variables and defaults

| Variable | Default | Purpose |
|-|-|-|
| crun_version | latest | The version of crun to install from the github releases. You can find them at: https://github.com/containers/crun/releases |
| crun_install_path | /opt/crun | The directory to install the crun binaries |

# Notes
The upgrade process will leave behind the previous version, this is by design.
The reason is so there can be a 0 downtime clean upgrade path.
The versions will only be downloaded if it does not alread exist.

This will only run on Linux systems due to Linux being the only OS supported by crun.
