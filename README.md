---

<p align="center">
  <img src="assets/logo.jpg" alt="Dumper Logo" width="360" />
</p>

# Dumper: A Tool To Dump Android ROM/Firmware.

---

---

## Introduction:

Dumper is a powerful extraction tool designed to extract partitions and information from Android firmware packages. It simplifies the process of extracting, analyzing, and organizing firmware components for developers, ROM builders, and Android enthusiasts.

### Features:

- Extract system, vendor, product, and other partitions from various firmware formats
- Support for multiple firmware packaging formats (zip, tar, ozip, ofp, ops, kdz, etc.)
- Intelligent detection of firmware type and automatic extraction
- Extract boot, recovery, dtbo images and analyze kernel information
- Generate proprietary-files lists with SHA1 checksums
- Generate TWRP and AOSP device trees
- Upload extracted firmware to GitHub/GitLab repositories
- Send notifications via Telegram

### Directory Structure:

- `input/`: Place your firmware files here
- `utils/`: Contains supportive tools and programs
- `out/`: Output directory for extracted files
  - `out/tmp/`: Temporary working directory

### Supported File Formats:

- Archives: `.zip`, `.rar`, `.7z`, `.tar`, `.tar.gz`, `.tgz`, `.tar.md5`
- Vendor formats: `.ozip`, `.ofp`, `.ops`, `.kdz`, `ruu_*exe`
- System images: `system.new.dat`, `system.new.dat.br`, `system.new.dat.xz`, `system.new.img`, `system.img`, `system-sign.img`, `UPDATE.APP`
- Other formats: `*.emmc.img`, `*.img.ext4`, `system.bin`, `system-p`, `payload.bin`, `*.nb0`, `.*chunk*`, `*.pac`, `*super*.img`, `*system*.sin`

---

---

## Installation:

### Prerequisites:

Clone this repository:
```bash
git clone https://github.com/techdiwas/Dumper.git
cd Dumper
```

### Automatic Setup:

Run the setup script to install all dependencies:
```bash
bash setup.sh
```

## Usage:

```bash
./dumper.sh <Firmware File/Extracted Folder -OR- Supported Website Link>
```

### Examples:

Extract from a local file:
```bash
./dumper.sh path/to/firmware.zip
```

Extract from a direct download link:
```bash
./dumper.sh 'https://example.com/firmware.zip'
```

Extract from a file hosting service:
```bash
./dumper.sh 'https://mega.nz/file/firmware.zip'
```

---

---

## Repository Integration:

Dumper can automatically push the extracted firmware to GitHub or GitLab repositories and send notifications to Telegram.

### GitHub Setup:

1. Create a `.github_token` file with your GitHub personal access token
2. (Optional) Create a `.github_orgname` file with your organization name

### GitLab Setup:

1. Create a `.gitlab_token` file with your GitLab personal access token
2. (Optional) Create a `.gitlab_group` file with your group name
3. (Optional) Create a `.gitlab_instance` file with your GitLab instance URL (default is gitlab.com)

### Telegram Notifications:

1. Create a `.tg_token` file with your Telegram bot token
2. (Optional) Create a `.tg_chat` file with your chat ID (default is @DumperDumps)

---

---

## Acknowledgements:

This project builds upon the work of various open-source tools and projects in the Android development community.

### Credit:

To all those oss developers who made this type of tool possible and made them available to others.
To all those developers who created tools that are being used in this project.
To name all of those developers here is not possible for now.
Thanks to all of them and lots of ❤️.

---

---

## License:

```md
    Dumper: A Tool To Dump Android ROM/Firmware.
    Copyright (C) 2025  Diwas Neupane (techdiwas)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
---

Built by ❤️
