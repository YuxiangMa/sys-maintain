# Enhanced System Maintenance Script

> Automated system maintenance script designed for Debian/Ubuntu systems.  
> Safe, modular, and extensible.

---

## Overview

This script automates various system maintenance tasks such as system updates, cache cleaning, old kernel removal, log cleanup, firmware updates, and more.  
After execution, a detailed report is generated for easy review of the maintenance results.

---

## Features

- Detects the operating system (supports Debian and Ubuntu).
- Updates package cache and performs system upgrades.
- Installs `linux-generic` package on Ubuntu.
- Removes old kernels, orphaned packages, and residual config files.
- Cleans up old Snap revisions, temporary directories, user caches, and trash.
- Vacuums journal logs older than 7 days.
- Repairs package database and cleans up old log files.
- Frees memory caches to improve system performance.
- Checks for and applies firmware updates (requires `fwupdmgr`).
- Logs all actions with a report saved in `/tmp`.

---

## Usage

1. Download the script:

    ```bash
    wget https://raw.githubusercontent.com/YuxiangMa/enhanced_system_maintenance.sh
    ```

2. Make it executable:

    ```bash
    chmod +x enhanced_system_maintenance.sh
    ```

3. Run the script as root:

    ```bash
    sudo ./enhanced_system_maintenance.sh
    ```

4. After completion, view the maintenance report:

    ```bash
    cat /tmp/system_maintenance_report_YYYYMMDD.log
    ```

    > Replace `YYYYMMDD` with the current date.

---

## Notes

- The script must be run as root; it will exit otherwise.
- Tested primarily on Debian and Ubuntu. Other distros are not guaranteed.
- Ensure `fwupdmgr` is installed to enable firmware update functionality.
- Uses strict error handling (`set -euo pipefail`), so execution may take some time.

---

## License

MIT License

---

Contributions and feedback are welcome!
