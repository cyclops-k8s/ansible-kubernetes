# Install crun Hook

This will install the crun runtime to replace runc which is used by default.

## Variables and defaults

| Variable | Default | Purpose |
| - | - | - |
| crun_version | latest | The version of crun to install from the github releases. You can find them at: <https://github.com/containers/crun/releases> |
| crun_install_path | /opt/crun | The directory to install the crun binaries |

## Notes

1. The upgrade process will leave behind the previous version. This is so there can be a zero downtime clean upgrade path.
1. The versions will only be downloaded if it does not already exist.
1. This will only run on Linux systems due to Linux being the only OS supported by crun.
