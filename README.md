Enhanced System Maintenance Script

This script automates comprehensive system maintenance tasks on Debian/Ubuntu servers.
Introduction

The script performs safe, modular, and extensible maintenance operations including system update, cleanup, kernel management, cache clearing, log cleaning, and firmware updates. It generates a detailed report for review.
Features

    Automatic OS detection (Debian/Ubuntu focused).

    Updates package cache and upgrades system packages.

    Installs linux-generic package (Ubuntu).

    Removes old kernels, orphaned packages, residual configs.

    Cleans snap revisions, temporary directories, user caches and trash.

    Vacuums journal logs older than 7 days.

    Repairs package database and cleans old log files.

    Drops memory caches to free RAM.

    Checks and applies firmware updates (if fwupdmgr is installed).

    Logs all actions with timestamps and writes summary report to /tmp.

Usage

Download the script:

wget https://raw.githubusercontent.com/YuxiangMa/enhanced_system_maintenance.sh

Make it executable:

chmod +x enhanced_system_maintenance.sh

Run as root:

sudo ./enhanced_system_maintenance.sh

After completion, check the detailed log report:

cat /tmp/system_maintenance_report_YYYYMMDD.log

Replace YYYYMMDD with the current date shown in the filename.
