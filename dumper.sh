#!/bin/bash

# Dumper - Firmware Extraction Tool
# A tool to extract partitions and information from Android firmware packages
# Copyright (C) 2025 Diwas Neupane (techdiwas)
# SPDX-License-Identifier: GPL-3.0-only
# ----------------------------------------------------------

# ------------------------------
# Initialize environment
# ------------------------------
setup_environment() {
    # Clear screen
    tput reset 2>/dev/null || clear
    
    # Unset all variables we'll use later
    unset PROJECT_DIR INPUTDIR UTILSDIR OUTDIR TMPDIR FILEPATH FILE EXTENSION UNZIP_DIR ArcPath \
        GITHUB_TOKEN GIT_ORG TG_TOKEN CHAT_ID
    
    # Resize terminal window for better view
    printf "\033[8;30;90t" || true
    
    # Set base project directory
    PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
    if echo "${PROJECT_DIR}" | grep " "; then
        echo "Error: Project directory path contains spaces. Place the script in a proper UNIX-formatted folder."
        exit 1
    fi
    
    # Setup directories
    INPUTDIR="${PROJECT_DIR}/input"     # Firmware download/preload directory
    UTILSDIR="${PROJECT_DIR}/utils"      # Contains supportive programs
    OUTDIR="${PROJECT_DIR}/out"          # Contains final extracted files
    TMPDIR="${OUTDIR}/tmp"              # Temporary working directory
    
    # Clean and create directories
    rm -rf "${TMPDIR}" 2>/dev/null
    mkdir -p "${OUTDIR}" "${TMPDIR}" 2>/dev/null
    
    # Define partition lists
    PARTITIONS="system system_ext system_other systemex vendor cust odm oem factory product xrom modem dtbo dtb boot vendor_boot recovery tz oppo_product preload_common opproduct reserve india my_preload my_bigball my_carrier my_custom my_engineering my_heytap my_manifest my_operator my_preload my_product my_region my_stock my_version"
    EXT4PARTITIONS="system vendor cust odm oem factory product xrom systemex oppo_product preload_common hw_product product_h preas preavs"
    OTHERPARTITIONS="tz.mbn:tz tz.img:tz modem.img:modem NON-HLOS:modem boot-verified.img:boot recovery-verified.img:recovery dtbo-verified.img:dtbo"
}

# ------------------------------
# Display banner and usage information
# ------------------------------
show_banner() {
    local GREEN='\033[0;32m'
    local NC='\033[0m'
    echo -e \
    ${GREEN}"
    ██████╗░██╗░░░██╗███╗░░░███╗██████╗░███████╗██████╗░
    ██╔══██╗██║░░░██║████╗░████║██╔══██╗██╔════╝██╔══██╗
    ██║░░██║██║░░░██║██╔████╔██║██████╔╝█████╗░░██████╔╝
    ██║░░██║██║░░░██║██║╚██╔╝██║██╔═══╝░██╔══╝░░██╔══██╗
    ██████╔╝╚██████╔╝██║░╚═╝░██║██║░░░░░███████╗██║░░██║
    ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝╚═╝░░░░░╚══════╝╚═╝░░╚═╝
    "${NC}
}

show_usage() {
    printf "  \e[1;32;40m \u2730 Usage: \$ %s <Firmware File/Extracted Folder -OR- Supported Website Link> \e[0m\n" "${0}"
    printf "\t\e[1;32m -> Firmware File: The .zip/.rar/.7z/.tar/.bin/.ozip/.kdz etc. file \e[0m\n\n"
    sleep .5s
    printf " \e[1;34m >> Supported Websites: \e[0m\n"
    printf "\e[36m\t1. Directly Accessible Download Link From Any Website\n"
    printf "\t2. Filehosters like - mega.nz | mediafire | gdrive | onedrive | androidfilehost\e[0m\n"
    printf "\t\e[33m >> Must Wrap Website Link Inside Single-quotes ('')\e[0m\n"
    sleep .2s
    printf " \e[1;34m >> Supported File Formats For Direct Operation:\e[0m\n"
    printf "\t\e[36m *.zip | *.rar | *.7z | *.tar | *.tar.gz | *.tgz | *.tar.md5\n"
    printf "\t *.ozip | *.ofp | *.ops | *.kdz | ruu_*exe\n"
    printf "\t system.new.dat | system.new.dat.br | system.new.dat.xz\n"
    printf "\t system.new.img | system.img | system-sign.img | UPDATE.APP\n"
    printf "\t *.emmc.img | *.img.ext4 | system.bin | system-p | payload.bin\n"
    printf "\t *.nb0 | .*chunk* | *.pac | *super*.img | *system*.sin\e[0m\n\n"
}

# ------------------------------
# Validate input arguments
# ------------------------------
validate_input() {
    if [[ $# = 0 ]]; then
        echo -e "\n  \e[1;31;40m \u2620 Error: No input is given.\e[0m\n"
        show_usage
        exit 1
    elif [[ "${1}" = "" ]]; then
        echo -e "\n  \e[1;31;40m ! Error: Enter firmware path.\e[0m\n"
        show_usage
        exit 1
    elif [[ "${1}" = " " || -n "$2" ]]; then
        echo -e "\n  \e[1;31;40m ! Error: Enter only firmware file path.\e[0m\n"
        show_usage
        exit 1
    fi
    
    # Display usage information by default
    show_usage
}

# ------------------------------
# Setup external tools
# ------------------------------
setup_tools() {
    EXTERNAL_TOOLS=(
        bkerler/oppo_ozip_decrypt
        bkerler/oppo_decrypt
        marin-m/vmlinux-to-elf
        ShivamKumarJha/android_tools
        HemanthJabalpuri/pacextractor
    )

    for tool_slug in "${EXTERNAL_TOOLS[@]}"; do
        if ! [[ -d "${UTILSDIR}"/"${tool_slug#*/}" ]]; then
            git clone -q https://github.com/"${tool_slug}".git "${UTILSDIR}"/"${tool_slug#*/}"
        else
            git -C "${UTILSDIR}"/"${tool_slug#*/}" pull
        fi
    done

    # Set utility program aliases
    SDAT2IMG="${UTILSDIR}"/sdat2img.py
    SIMG2IMG="${UTILSDIR}"/bin/simg2img
    PACKSPARSEIMG="${UTILSDIR}"/bin/packsparseimg
    UNSIN="${UTILSDIR}"/unsin
    PAYLOAD_EXTRACTOR="${UTILSDIR}"/bin/payload-dumper-go
    DTC="${UTILSDIR}"/dtc
    VMLINUX2ELF="${UTILSDIR}"/vmlinux-to-elf/vmlinux-to-elf
    KALLSYMS_FINDER="${UTILSDIR}"/vmlinux-to-elf/kallsyms-finder
    OZIPDECRYPT="${UTILSDIR}"/oppo_ozip_decrypt/ozipdecrypt.py
    OFP_QC_DECRYPT="${UTILSDIR}"/oppo_decrypt/ofp_qc_decrypt.py
    OFP_MTK_DECRYPT="${UTILSDIR}"/oppo_decrypt/ofp_mtk_decrypt.py
    OPSDECRYPT="${UTILSDIR}"/oppo_decrypt/opscrypto.py
    LPUNPACK="${UTILSDIR}"/lpunpack
    SPLITUAPP="${UTILSDIR}"/splituapp.py
    PACEXTRACTOR="${UTILSDIR}"/pacextractor/python/pacExtractor.py
    NB0_EXTRACT="${UTILSDIR}"/nb0-extract
    KDZ_EXTRACT="${UTILSDIR}"/kdztools/unkdz.py
    DZ_EXTRACT="${UTILSDIR}"/kdztools/undz.py
    RUUDECRYPT="${UTILSDIR}"/RUU_Decrypt_Tool
    EXTRACT_IKCONFIG="${UTILSDIR}"/extract-ikconfig
    UNPACKBOOT="${UTILSDIR}"/unpackboot.sh
    AML_EXTRACT="${UTILSDIR}"/aml-upgrade-package-extract
    AFPTOOL_EXTRACT="${UTILSDIR}"/bin/afptool
    RK_EXTRACT="${UTILSDIR}"/bin/rkImageMaker
    TRANSFER="${UTILSDIR}"/bin/transfer
    FSCK_EROFS="${UTILSDIR}"/bin/fsck.erofs

    # Check for 7zz
    if ! command -v 7zz > /dev/null 2>&1; then
        BIN_7ZZ="${UTILSDIR}"/bin/7zz
    else
        BIN_7ZZ=7zz
    fi

    # Check for uvx
    if ! command -v uvx > /dev/null 2>&1; then
        export PATH="${HOME}/.local/bin:${PATH}"
    fi

    # Set downloader utility programs
    MEGAMEDIADRIVE_DL="${UTILSDIR}"/downloaders/mega-media-drive_dl.sh
    AFHDL="${UTILSDIR}"/downloaders/afh_dl.py
}

# ------------------------------
# Process input file or URL
# ------------------------------
process_input() {
    local input_source="$1"
    
    # Handle input from project input directory
    if echo "${input_source}" | grep -q "${PROJECT_DIR}/input" && [[ $(find "${INPUTDIR}" -maxdepth 1 -type f -size +10M -print | wc -l) -gt 1 ]]; then
        FILEPATH=$(realpath "${input_source}")
        echo "Copying everything into ${TMPDIR} for further operations."
        cp -a "${FILEPATH}"/* "${TMPDIR}"/
        unset FILEPATH
    elif echo "${input_source}" | grep -q "${PROJECT_DIR}/input/" && [[ $(find "${INPUTDIR}" -maxdepth 1 -type f -size +300M -print | wc -l) -eq 1 ]]; then
        echo "Input directory exists and contains file"
        cd "${INPUTDIR}"/ || exit
        FILEPATH=$(find "$(pwd)" -maxdepth 1 -type f -size +300M 2>/dev/null)
        FILE=${FILEPATH##*/}
        EXTENSION=${FILEPATH##*.}
        if echo "${EXTENSION}" | grep -q "zip\|rar\|7z\|tar$"; then
            UNZIP_DIR=${FILE%.*}
        fi
    else
        # Handle URL or local file/folder
        process_url_or_local "$input_source"
    fi
}

# Process URL or local file/folder
process_url_or_local() {
    local input_source="$1"
    
    # Check if it's a URL
    if echo "${input_source}" | grep -q -e '^\(https\?\|ftp\)://.*$' >/dev/null; then
        download_from_url "${input_source}"
    else
        # Process local file/folder
        FILEPATH=$(realpath "${input_source}")
        if echo "${input_source}" | grep " "; then
            if [[ -w "${FILEPATH}" ]]; then
                detox -r "${FILEPATH}" 2>/dev/null
                FILEPATH=$(echo "${FILEPATH}" | inline-detox)
            fi
        fi
        
        if [[ ! -e "${FILEPATH}" ]]; then
            echo "Error: Input file/folder doesn't exist"
            exit 1
        fi
        
        # Set file variables
        FILE=${FILEPATH##*/}
        EXTENSION=${FILEPATH##*.}
        if echo "${EXTENSION}" | grep -q "zip\|rar\|7z\|tar$"; then
            UNZIP_DIR=${FILE%.*}
        fi
        
        # Handle directory input
        process_directory_input
    fi
}

# Download file from URL
download_from_url() {
    local URL="$1"
    
    mkdir -p "${INPUTDIR}" 2>/dev/null
    cd "${INPUTDIR}"/ || exit
    rm -rf "${INPUTDIR:?}"/* 2>/dev/null
    
    if echo "${URL}" | grep -q "mega.nz\|mediafire.com\|drive.google.com"; then
        ("${MEGAMEDIADRIVE_DL}" "${URL}") || exit 1
    elif echo "${URL}" | grep -q "androidfilehost.com"; then
        (python3 "${AFHDL}" -l "${URL}") || exit 1
    elif echo "${URL}" | grep -q "/we.tl/"; then
        ("${TRANSFER}" "${URL}") || exit 1
    else
        if echo "${URL}" | grep -q "1drv.ms"; then 
            URL=${URL/ms/ws}
        fi
        aria2c -x16 -s8 --console-log-level=warn --summary-interval=0 --check-certificate=false "${URL}" || {
            wget -q --show-progress --progress=bar:force --no-check-certificate "${URL}" || exit 1
        }
    fi
    
    # Clean up filenames
    for f in *; do 
        detox -r "${f}" 2>/dev/null
    done
    
    # Set input file variables
    FILEPATH=$(find "$(pwd)" -maxdepth 1 -type f 2>/dev/null)
    echo -e "\nWorking with ${FILEPATH##*/}\n"
    
    # If multiple files were downloaded, treat as folder
    [[ $(echo "${FILEPATH}" | tr ' ' '\n' | wc -l) -gt 1 ]] && FILEPATH=$(find "$(pwd)" -maxdepth 2 -type d)
}

# Process directory input
process_directory_input() {
    if [[ -d "${FILEPATH}" || "${EXTENSION}" == "" ]]; then
        echo "Directory detected."
        
        # Check if folder contains compressed archives
        if find "${FILEPATH}" -maxdepth 1 -type f | grep -v "compatibility.zip" | grep -q ".*.tar$\|.*.zip\|.*.rar\|.*.7z"; then
            echo "Supplied folder has compressed archive that needs to be re-loaded"
            
            # Find archive in download directory
            ArcPath=$(find "${INPUTDIR}"/ -maxdepth 1 -type f \( -name "*.tar" -o -name "*.zip" -o -name "*.rar" -o -name "*.7z" \) -print | grep -v "compatibility.zip")
            
            # If empty, check original local folder
            [[ -z "${ArcPath}" ]] && ArcPath=$(find "${FILEPATH}"/ -maxdepth 1 -type f \( -name "*.tar" -o -name "*.zip" -o -name "*.rar" -o -name "*.7z" \) -print | grep -v "compatibility.zip")
            
            # Process archive if exactly one is found
            if ! echo "${ArcPath}" | grep -q " "; then
                cd "${PROJECT_DIR}"/ || exit
                (bash "${0}" "${ArcPath}") || exit 1
                exit
            elif echo "${ArcPath}" | grep -q " "; then
                echo "More than one archive file is available in ${FILEPATH} folder. Please use direct archive path along with this toolkit."
                exit 1
            fi
        # Check if folder contains firmware files
        elif find "${FILEPATH}" -maxdepth 1 -type f | grep ".*system.ext4.tar.*\|.*chunk\|system\/build.prop\|system.new.dat\|system_new.img\|system.img\|system-sign.img\|system.bin\|payload.bin\|.*rawprogram*\|system.ext4\|tar.md5\|.*.nb0\|.*.img\|.*.zip\|.*.rar\|.*.7z\|.*.tar$\|super\|UPDATE.APP\|.*.sin\|.*.pac\|system.sina\|system_other.sina\|vendor.sina\|.*.ozip\|.*.ops\|.*.ofp"; then
            echo "Copying everything into ${TMPDIR} for further operations."
            cp -a "${FILEPATH}"/* "${TMPDIR}"/
            unset FILEPATH
        else
            echo -e "\e[31m Error: This type of firmware is not supported.\e[0m"
            cd "${PROJECT_DIR}"/ || exit
            rm -rf "${TMPDIR}" "${OUTDIR}"
            exit 1
        fi
    fi
}

# ------------------------------
# Extract super images
# ------------------------------
superimage_extract() {
    if [ -f super.img ]; then
        echo "Extracting partitions from the super image..."
        ${SIMG2IMG} super.img super.img.raw 2>/dev/null
    fi
    
    if [[ ! -s super.img.raw ]] && [ -f super.img ]; then
        mv super.img super.img.raw
    fi
    
    # Extract each partition
    for partition in $PARTITIONS; do
        ($LPUNPACK --partition="$partition"_a super.img.raw || $LPUNPACK --partition="$partition" super.img.raw) 2>/dev/null
        
        if [ -f "$partition"_a.img ]; then
            mv "$partition"_a.img "$partition".img
        else
            foundpartitions=$(${BIN_7ZZ} l -ba "${FILEPATH}" | rev | gawk '{ print $1 }' | rev | grep $partition.img)
            ${BIN_7ZZ} e -y "${FILEPATH}" $foundpartitions dummypartition 2>/dev/null >> $TMPDIR/zip.log
        fi
    done
    
    rm -rf super.img.raw
}

# ------------------------------
# Process different firmware types
# ------------------------------
process_firmware() {
    cd "${TMPDIR}"/ || exit
    
    # Detect and process specific firmware types
    if [[ $(head -c12 "${FILEPATH}" 2>/dev/null | tr -d '\0') == "OPPOENCRYPT!" ]] || [[ "${EXTENSION}" == "ozip" ]]; then
        process_oppo_ozip
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q ".*.ops" 2>/dev/null; then
        process_oppo_ops_from_archive
    elif [[ "${EXTENSION}" == "ops" ]]; then
        process_oppo_ops
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep -q ".*.ofp" 2>/dev/null; then
        process_oppo_ofp_from_archive
    elif [[ "${EXTENSION}" == "ofp" ]]; then
        process_oppo_ofp
    elif [[ "${FILE##*.}" == "tgz" || "${FILE#*.}" == "tar.gz" ]]; then
        process_xiaomi_tgz
    elif echo "${FILEPATH}" | grep -q ".*.kdz" || [[ "${EXTENSION}" == "kdz" ]]; then
        process_lg_kdz
    elif echo "${FILEPATH}" | grep -i "^ruu_" | grep -q -i "exe$" || [[ "${EXTENSION}" == "exe" ]]; then
        process_htc_ruu
    elif [[ $(${BIN_7ZZ} l -ba "${FILEPATH}" | grep -i aml) ]]; then
        process_amlogic_package
    else
        # Process general firmware
        process_general_firmware
    fi
}

# Process OPPO ozip firmware
process_oppo_ozip() {
    echo "Oppo/Realme ozip detected."
    # Either move downloaded/re-loaded file or copy local file
    mv -f "${INPUTDIR}"/"${FILE}" "${TMPDIR}"/"${FILE}" 2>/dev/null || cp -a "${FILEPATH}" "${TMPDIR}"/"${FILE}"
    echo "Decrypting ozip and making a zip..."
    uv run --with-requirements "${UTILSDIR}/oppo_decrypt/requirements.txt" "${OZIPDECRYPT}" "${TMPDIR}"/"${FILE}"
    
    mkdir -p "${INPUTDIR}" 2>/dev/null && rm -rf -- "${INPUTDIR:?}"/* 2>/dev/null
    if [[ -f "${FILE%.*}".zip ]]; then
        mv "${FILE%.*}".zip "${INPUTDIR}"/
    elif [[ -d "${TMPDIR}"/out ]]; then
        mv "${TMPDIR}"/out/* "${INPUTDIR}"/
    fi
    
    rm -rf "${TMPDIR:?}"/*
    echo "Re-loading the decrypted content."
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/" 2>/dev/null || bash "${0}" "${INPUTDIR}"/"${FILE%.*}".zip) || exit 1
    exit
}

# Process OPPO ops from archive
process_oppo_ops_from_archive() {
    echo "Oppo/Oneplus ops firmware detected. Extracting..."
    foundops=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep ".*.ops")
    ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundops}" */"${foundops}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    mkdir -p "${INPUTDIR}" 2>/dev/null && rm -rf -- "${INPUTDIR:?}"/* 2>/dev/null
    mv "$(echo "${foundops}" | gawk -F['/'] '{print $NF}')" "${INPUTDIR}"/
    sleep 1s
    
    echo "Reloading the extracted OPS"
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/${foundops}" 2>/dev/null) || exit 1
    exit
}

# Process OPPO ops firmware
process_oppo_ops() {
    echo "Oppo/Oneplus ops detected."
    # Either move downloaded/re-loaded file or copy local file
    mv -f "${INPUTDIR}"/"${FILE}" "${TMPDIR}"/"${FILE}" 2>/dev/null || cp -a "${FILEPATH}" "${TMPDIR}"/"${FILE}"
    echo "Decrypting ops & extracting..."
    uv run --with-requirements "${UTILSDIR}/oppo_decrypt/requirements.txt" "${OPSDECRYPT}" decrypt "${TMPDIR}"/"${FILE}"
    
    mkdir -p "${INPUTDIR}" 2>/dev/null && rm -rf -- "${INPUTDIR:?}"/* 2>/dev/null
    mv "${TMPDIR}"/extract/* "${INPUTDIR}"/
    rm -rf "${TMPDIR:?}"/*
    
    echo "Re-loading the decrypted content."
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/" 2>/dev/null || bash "${0}" "${INPUTDIR}"/"${FILE%.*}".zip) || exit 1
    exit
}

# Process OPPO ofp from archive
process_oppo_ofp_from_archive() {
    echo "Oppo ofp detected."
    foundofp=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep ".*.ofp")
    ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundofp}" */"${foundofp}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    mkdir -p "${INPUTDIR}" 2>/dev/null && rm -rf -- "${INPUTDIR:?}"/* 2>/dev/null
    mv "$(echo "${foundofp}" | gawk -F['/'] '{print $NF}')" "${INPUTDIR}"/
    sleep 1s
    
    echo "Reloading the extracted OFP"
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/${foundofp}" 2>/dev/null) || exit 1
    exit
}

# Process OPPO ofp firmware
process_oppo_ofp() {
    echo "Oppo ofp detected."
    # Either move downloaded/re-loaded file or copy local file
    mv -f "${INPUTDIR}"/"${FILE}" "${TMPDIR}"/"${FILE}" 2>/dev/null || cp -a "${FILEPATH}" "${TMPDIR}"/"${FILE}"
    echo "Decrypting ofp & extracting..."
    
    uv run --with-requirements "${UTILSDIR}/oppo_decrypt/requirements.txt" "$OFP_QC_DECRYPT" "${TMPDIR}"/"${FILE}" out
    if [[ ! -f "${TMPDIR}"/out/boot.img || ! -f "${TMPDIR}"/out/userdata.img ]]; then
        uv run --with-requirements "${UTILSDIR}/oppo_decrypt/requirements.txt" "$OFP_MTK_DECRYPT" "${TMPDIR}"/"${FILE}" out
        if [[ ! -f "${TMPDIR}"/out/boot.img || ! -f "${TMPDIR}"/out/userdata.img ]]; then
            echo "ofp decryption error." && exit 1
        fi
    fi
    
    mkdir -p "${INPUTDIR}" 2>/dev/null && rm -rf -- "${INPUTDIR:?}"/* 2>/dev/null
    if [[ -d "${TMPDIR}"/out ]]; then
        mv "${TMPDIR}"/out/* "${INPUTDIR}"/
    fi
    rm -rf "${TMPDIR:?}"/*
    
    echo "Re-loading the decrypted contents."
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/") || exit 1
    exit
}

# Process Xiaomi tgz firmware
process_xiaomi_tgz() {
    echo "Xiaomi gzipped tar archive found."
    mkdir -p "${INPUTDIR}" 2>/dev/null
    if [[ -f "${INPUTDIR}"/"${FILE}" ]]; then
        tar xzvf "${INPUTDIR}"/"${FILE}" -C "${INPUTDIR}"/ --transform='s/.*\///'
        rm -rf -- "${INPUTDIR:?}"/"${FILE}"
    elif [[ -f "${FILEPATH}" ]]; then
        tar xzvf "${FILEPATH}" -C "${INPUTDIR}"/ --transform='s/.*\///'
    fi
    
    find "${INPUTDIR}"/ -type d -empty -delete     # Delete empty folder leftover
    rm -rf "${TMPDIR:?}"/*
    
    echo "Re-loading the extracted contents."
    cd "${PROJECT_DIR}"/ || exit
    (bash "${0}" "${PROJECT_DIR}/input/") || exit 1
    exit
}

# Process LG KDZ firmware
process_lg_kdz() {
    echo "LG KDZ detected."
    # Either move downloaded/re-loaded file or copy local file
    mv -f "${INPUTDIR}"/"${FILE}" "${TMPDIR}"/ 2>/dev/null || cp -a "${FILEPATH}" "${TMPDIR}"/
    python3 "${KDZ_EXTRACT}" -f "${FILE}" -x -o "./" 2>/dev/null
    DZFILE=$(ls -- *.dz)
    echo "Extracting all partitions as individual images."
    python3 "${DZ_EXTRACT}" -f "${DZFILE}" -s -o "./" 2>/dev/null
    rm -f "${TMPDIR}"/"${FILE}" "${TMPDIR}"/"${DZFILE}" 2>/dev/null
    
    # Rename image files appropriately
    find "${TMPDIR}" -maxdepth 1 -type f -name "*.image" | while read -r i; do mv "${i}" "${i/.image/.img}" 2>/dev/null; done
    find "${TMPDIR}" -maxdepth 1 -type f -name "*_a.img" | while read -r i; do mv "${i}" "${i/_a.img/.img}" 2>/dev/null; done
    find "${TMPDIR}" -maxdepth 1 -type f -name "*_b.img" -exec rm -rf {} \;
}

# Process HTC RUU firmware
process_htc_ruu() {
    echo "HTC RUU detected."
    # Either move downloaded/re-loaded file or copy local file
    mv -f "${INPUTDIR}"/"${FILE}" "${TMPDIR}"/ || cp -a "${FILEPATH}" "${TMPDIR}"/
    echo "Extracting system and firmware partitions..."
    "${RUUDECRYPT}" -s "${FILE}" 2>/dev/null
    "${RUUDECRYPT}" -f "${FILE}" 2>/dev/null
    find "${TMPDIR}"/OUT* -name "*.img" -exec mv {} "${TMPDIR}"/ \;
}

# Process Amlogic package
process_amlogic_package() {
    echo "AML detected"
    cp "${FILEPATH}" ${TMPDIR}
    FILE="${TMPDIR}/$(basename ${FILEPATH})"
    ${BIN_7ZZ} e -y "${FILEPATH}" >> ${TMPDIR}/zip.log
    "${AML_EXTRACT}" $(find . -type f -name "*aml*.img")
    rename 's/.PARTITION$/.img/' *.PARTITION
    rename 's/_aml_dtb.img$/dtb.img/' *.img
    rename 's/_a.img/.img/' *.img
    
    if [[ -f super.img ]]; then
        superimage_extract || exit 1
    fi
    
    for partition in $PARTITIONS; do
        [[ -e "${TMPDIR}/${partition}.img" ]] && mv "${TMPDIR}/${partition}.img" "${OUTDIR}/${partition}.img"
    done
    
    rm -rf ${TMPDIR}
}

# Process general firmware types
process_general_firmware() {
    # Extract & move raw other partitions to OUTDIR
    extract_other_partitions_from_archive
    
    # Detect and process specific firmware formats
    if ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "system.new.dat" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "system.new.dat*" -print | wc -l) -ge 1 ]]; then
        process_dat_ota
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep rawprogram || [[ $(find "${TMPDIR}" -type f -name "*rawprogram*" | wc -l) -ge 1 ]]; then
        process_qfil
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q ".*.nb0" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "*.nb0*" | wc -l) -ge 1 ]]; then
        process_nb0
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep system | grep chunk | grep -q -v ".*\.so$" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "*system*chunk*" | wc -l) -ge 1 ]]; then
        process_chunk
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep -q "system_new.img\|^system.img\|\/system.img\|\/system_image.emmc.img\|^system_image.emmc.img" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "*system*.img*" | wc -l) -ge 1 ]]; then
        process_system_image
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "system.sin\|.*system_.*\.sin" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "system*.sin" | wc -l) -ge 1 ]]; then
        process_sin_image
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep ".pac$" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "*.pac" | wc -l) -ge 1 ]]; then
        process_pac
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "system.bin" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "system.bin" | wc -l) -ge 1 ]]; then
        process_bin_images
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "system-p" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "system-p*" | wc -l) -ge 1 ]]; then
        process_p_suffix_images
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "system-sign.img" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "system-sign.img" | wc -l) -ge 1 ]]; then
        process_signed_images
    elif [[ $(${BIN_7ZZ} l -ba "$FILEPATH" | grep "super.img") ]]; then
        process_super_image
    elif [[ $(find "${TMPDIR}" -type f -name "super*.*img" | wc -l) -ge 1 ]]; then
        process_split_super_image
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep tar.md5 | gawk '{print $NF}' | grep -q AP_ 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "*AP_*tar.md5" | wc -l) -ge 1 ]]; then
        process_ap_tarmd5
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q payload.bin 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "payload.bin" | wc -l) -ge 1 ]]; then
        process_ab_ota_payload
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep ".*.rar\|.*.zip\|.*.7z\|.*.tar$" 2>/dev/null || [[ $(find "${TMPDIR}" -type f \( -name "*.rar" -o -name "*.zip" -o -name "*.7z" -o -name "*.tar" \) | wc -l) -ge 1 ]]; then
        process_archive
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "UPDATE.APP" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "UPDATE.APP") ]]; then
        process_huawei_update_app
    elif ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "rockchip" 2>/dev/null || [[ $(find "${TMPDIR}" -type f -name "rockchip") ]]; then
        process_rockchip
    fi
}

# Extract other partitions from archive
extract_other_partitions_from_archive() {
    if [[ -f "${FILEPATH}" ]]; then
        for otherpartition in ${OTHERPARTITIONS}; do
            filename=${otherpartition%:*} && outname=${otherpartition#*:}
            if ${BIN_7ZZ} l -ba "${FILEPATH}" | grep -q "${filename}"; then
                echo "${filename} detected for ${outname}"
                foundfile=$(${BIN_7ZZ} l -ba "${FILEPATH}" | grep "${filename}" | awk '{print $NF}')
                ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundfile}" */"${foundfile}" 2>/dev/null >> "${TMPDIR}"/zip.log
                output=$(ls -- "${filename}"* 2>/dev/null)
                [[ ! -e "${TMPDIR}"/"${outname}".img ]] && mv "${output}" "${TMPDIR}"/"${outname}".img
                "${SIMG2IMG}" "${TMPDIR}"/"${outname}".img "${OUTDIR}"/"${outname}".img 2>/dev/null
                [[ ! -s "${OUTDIR}"/"${outname}".img && -f "${TMPDIR}"/"${outname}".img ]] && mv "${outname}".img "${OUTDIR}"/"${outname}".img
            fi
        done
    fi
}

# Process DAT-formatted OTA
process_dat_ota() {
    echo "A-only DAT-formatted OTA detected."
    for partition in $PARTITIONS; do
        ${BIN_7ZZ} e -y "${FILEPATH}" ${partition}.new.dat* ${partition}.transfer.list ${partition}.img 2>/dev/null >> ${TMPDIR}/zip.log
        ${BIN_7ZZ} e -y "${FILEPATH}" ${partition}.*.new.dat* ${partition}.*.transfer.list ${partition}.*.img 2>/dev/null >> ${TMPDIR}/zip.log
        
        # Fix Oplus A-only OTAs filenames
        rename 's/(\w+)\.(\d+)\.(\w+)/$1.$3/' *
        
        # Combine split files if needed
        if [[ -f ${partition}.new.dat.1 ]]; then
            cat ${partition}.new.dat.{0..999} 2>/dev/null >> ${partition}.new.dat
            rm -rf ${partition}.new.dat.{0..999}
        fi
        
        # Process each dat file
        ls | grep "\.new\.dat" | while read i; do
            line=$(echo "$i" | cut -d"." -f1)
            
            # Extract compressed dat files
            if [[ $(echo "$i" | grep "\.dat\.xz") ]]; then
                ${BIN_7ZZ} e -y "$i" 2>/dev/null >> ${TMPDIR}/zip.log
                rm -rf "$i"
            fi
            
            if [[ $(echo "$i" | grep "\.dat\.br") ]]; then
                echo "Converting brotli ${partition} dat to normal"
                brotli -d "$i"
                rm -f "$i"
            fi
            
            echo "Extracting ${partition}"
            python3 ${SDAT2IMG} ${line}.transfer.list ${line}.new.dat "${OUTDIR}"/${line}.img > ${TMPDIR}/extract.log
            rm -rf ${line}.transfer.list ${line}.new.dat
        done
    done
}

# Process QFIL firmware
process_qfil() {
    echo "QFIL detected"
    rawprograms=$(${BIN_7ZZ} l -ba ${FILEPATH} | gawk '{ print $NF }' | grep rawprogram)
    ${BIN_7ZZ} e -y ${FILEPATH} $rawprograms 2>/dev/null >> ${TMPDIR}/zip.log
    
    for partition in $PARTITIONS; do
        partitionsonzip=$(${BIN_7ZZ} l -ba ${FILEPATH} | gawk '{ print $NF }' | grep $partition)
        if [[ ! $partitionsonzip == "" ]]; then
            ${BIN_7ZZ} e -y ${FILEPATH} $partitionsonzip 2>/dev/null >> ${TMPDIR}/zip.log
            if [[ ! -f "$partition.img" ]]; then
                if [[ -f "$partition.raw.img" ]]; then
                    mv "$partition.raw.img" "$partition.img"
                else
                    rawprogramsfile=$(grep -rlw $partition rawprogram*.xml)
                    "${PACKSPARSEIMG}" -t $partition -x $rawprogramsfile > ${TMPDIR}/extract.log
                    mv "$partition.raw" "$partition.img"
                fi
            fi
        fi
    done
    
    if [[ -f super.img ]]; then
        superimage_extract || exit 1
    fi
}

# Process nb0 firmware
process_nb0() {
    echo "nb0-formatted firmware detected."
    if [[ -f "${FILEPATH}" ]]; then
        to_extract=$(${BIN_7ZZ} l -ba "${FILEPATH}" | grep ".*.nb0" | gawk '{print $NF}')
        ${BIN_7ZZ} e -y -- "${FILEPATH}" "${to_extract}" 2>/dev/null >> "${TMPDIR}"/zip.log
    else
        find "${TMPDIR}" -type f -name "*.nb0*" -exec mv {} . \; 2>/dev/null
    fi
    "${NB0_EXTRACT}" "${to_extract}" "${TMPDIR}"
}

# Process chunk firmware
process_chunk() {
    echo "Chunk detected."
    for partition in ${PARTITIONS}; do
        if [[ -f "${FILEPATH}" ]]; then
            foundpartitions=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep "${partition}".img)
            ${BIN_7ZZ} e -y -- "${FILEPATH}" *"${partition}"*chunk* */*"${partition}"*chunk* "${foundpartitions}" dummypartition 2>/dev/null >> "${TMPDIR}"/zip.log
        else
            find "${TMPDIR}" -type f -name "*${partition}*chunk*" -exec mv {} . \; 2>/dev/null
            find "${TMPDIR}" -type f -name "*${partition}*.img" -exec mv {} . \; 2>/dev/null
        fi
        
        # Remove unnecessary files
        rm -f -- *"${partition}"_b*
        rm -f -- *"${partition}"_other*
        
        # Process chunk files
        romchunk=$(find . -maxdepth 1 -type f -name "*${partition}*chunk*" | cut -d'/' -f'2-' | sort)
        if echo "${romchunk}" | grep -q "sparsechunk"; then
            if [[ ! -f "${partition}".img ]]; then
                "${SIMG2IMG}" "${romchunk}" "${partition}".img.raw 2>/dev/null
                mv "${partition}".img.raw "${partition}".img
            fi
            rm -rf -- *"${partition}"*chunk* 2>/dev/null
        fi
    done
}

# Process system image files
process_system_image() {
    echo "Image file detected."
    if [[ -f "${FILEPATH}" ]]; then
        ${BIN_7ZZ} x -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    fi
    
    # Clean filenames
    for f in "${TMPDIR}"/*; do 
        detox -r "${f}" 2>/dev/null
    done
    
    # Rename image files for consistency
    find "${TMPDIR}" -mindepth 2 -type f -name "*_image.emmc.img" | while read -r i; do mv "${i}" "${i/_image.emmc.img/.img}" 2>/dev/null; done
    find "${TMPDIR}" -mindepth 2 -type f -name "*_new.img" | while read -r i; do mv "${i}" "${i/_new.img/.img}" 2>/dev/null; done
    find "${TMPDIR}" -mindepth 2 -type f -name "*.img.ext4" | while read -r i; do mv "${i}" "${i/.img.ext4/.img}" 2>/dev/null; done
    find "${TMPDIR}" -mindepth 2 -type f -name "*.img" -exec mv {} . \;    # move .img in sub-dir to ${TMPDIR}
    
    # Keep some informational files
    find "${TMPDIR}" -type f -iname "*Android_scatter.txt" -exec mv {} "${OUTDIR}"/ \;
    find "${TMPDIR}" -type f -iname "*Release_Note.txt" -exec mv {} "${OUTDIR}"/ \;
    
    # Delete other files and reorganize
    find "${TMPDIR}" -type f ! -name "*img*" -exec rm -rf {} \;    # delete other files
    find "${TMPDIR}" -maxdepth 3 -type f -name "*.img" -exec mv {} . \; 2>/dev/null
}

# Process sin image files
process_sin_image() {
    echo "sin image detected."
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} x -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    # Find pattern to remove from filenames
    to_remove=$(find . -type f | grep ".*boot_.*\.sin" | gawk '{print $NF}' | sed -e 's/boot_\(.*\).sin/\1/')
    [[ -z "$to_remove" ]] && to_remove=$(find . -type f | grep ".*cache_.*\.sin" | gawk '{print $NF}' | sed -e 's/cache_\(.*\).sin/\1/')
    [[ -z "$to_remove" ]] && to_remove=$(find . -type f | grep ".*vendor_.*\.sin" | gawk '{print $NF}' | sed -e 's/vendor_\(.*\).sin/\1/')
    
    # Move and rename sin files
    find "${TMPDIR}" -mindepth 2 -type f -name "*.sin" -exec mv {} . \;
    find "${TMPDIR}" -maxdepth 1 -type f -name "*_${to_remove}.sin" | while read -r i; do mv "${i}" "${i/_${to_remove}.sin/.sin}" 2>/dev/null; done
    
    # Extract sin files
    "${UNSIN}" -d "${TMPDIR}"
    
    # Rename extracted files
    find "${TMPDIR}" -maxdepth 1 -type f -name "*.ext4" | while read -r i; do mv "${i}" "${i/.ext4/.img}" 2>/dev/null; done
    
    # Process super image if found
    foundsuperinsin=$(find "${TMPDIR}" -maxdepth 1 -type f -name "super_*.img")
    if [ ! -z $foundsuperinsin ]; then
        mv $(ls ${TMPDIR}/super_*.img) "${TMPDIR}/super.img"
        echo "Super image inside a sin detected"
        superimage_extract || exit 1
    fi
}

# Process pac files
process_pac() {
    echo "pac detected."
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} x -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    # Clean filenames
    for f in "${TMPDIR}"/*; do 
        detox -r "${f}"
    done
    
    # Process each pac file
    pac_list=$(find . -type f -name "*.pac" | cut -d'/' -f'2-' | sort)
    for file in ${pac_list}; do
        python3 "${PACEXTRACTOR}" "${file}" $(pwd)
    done
    
    # Process super image if found
    if [[ -f super.img ]]; then
        superimage_extract || exit 1
    fi
}

# Process bin image files
process_bin_images() {
    echo "bin images detected"
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} x -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    # Move and rename bin files
    find "${TMPDIR}" -mindepth 2 -type f -name "*.bin" -exec mv {} . \;
    find "${TMPDIR}" -maxdepth 1 -type f -name "*.bin" | while read -r i; do mv "${i}" "${i/\.bin/.img}" 2>/dev/null; done
}

# Process p-suffix images
process_p_suffix_images() {
    echo "p-suffix images detected"
    for partition in ${PARTITIONS}; do
        if [[ -f "${FILEPATH}" ]]; then
            foundpartitions=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep "${partition}-p")
            ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundpartitions}" dummypartition 2>/dev/null >> "${TMPDIR}"/zip.log
        else
            foundpartitions=$(find . -type f -name "*${partition}-p*" | cut -d'/' -f'2-')
        fi
        [[ -n "${foundpartitions}" ]] && mv "$(ls "${partition}"-p*)" "${partition}".img
    done
}

# Process signed images
process_signed_images() {
    echo "Signed images detected"
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} x -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    # Clean filenames
    for f in "${TMPDIR}"/*; do 
        detox -r "${f}"
    done
    
    # Move pre-processed images to output
    for partition in ${PARTITIONS}; do
        [[ -e "${TMPDIR}"/"${partition}".img ]] && mv "${TMPDIR}"/"${partition}".img "${OUTDIR}"/"${partition}".img
    done
    
    # Move and clean up other files
    find "${TMPDIR}" -mindepth 2 -type f -name "*-sign.img" -exec mv {} . \;
    find "${TMPDIR}" -type f ! -name "*-sign.img" -exec rm -rf {} \;
    find "${TMPDIR}" -maxdepth 1 -type f -name "*-sign.img" | while read -r i; do mv "${i}" "${i/-sign.img/.img}" 2>/dev/null; done
    
    # Process signed images
    sign_list=$(find . -maxdepth 1 -type f -name "*.img" | cut -d'/' -f'2-' | sort)
    for file in ${sign_list}; do
        rm -rf "${TMPDIR}"/x.img >/dev/null 2>&1
        MAGIC=$(head -c4 "${TMPDIR}"/"${file}" | tr -d '\0')
        if [[ "${MAGIC}" == "SSSS" ]]; then
            echo "Cleaning ${file} with SSSS header"
            # For little_endian architecture
            offset_low=$(od -A n -x -j 60 -N 2 "${TMPDIR}"/"${file}" | sed 's/ //g')
            offset_high=$(od -A n -x -j 62 -N 2 "${TMPDIR}"/"${file}" | sed 's/ //g')
            offset_low=0x${offset_low:0-4}
            offset_high=0x${offset_high:0-4}
            offset_low=$(printf "%d" "${offset_low}")
            offset_high=$(printf "%d" "${offset_high}")
            offset=$((65536*offset_high+offset_low))
            dd if="${TMPDIR}"/"${file}" of="${TMPDIR}"/x.img iflag=count_bytes,skip_bytes bs=8192 skip=64 count=${offset} >/dev/null 2>&1
        else    # Header with BFBF magic or another unknown header
            dd if="${TMPDIR}"/"${file}" of="${TMPDIR}"/x.img bs=$((0x4040)) skip=1 >/dev/null 2>&1
        fi
    done
}

# Process super image
process_super_image() {
    echo "Super image detected"
    foundsupers=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{ print $NF }' | grep "super.img")
    ${BIN_7ZZ} e -y "${FILEPATH}" $foundsupers dummypartition 2>/dev/null >> ${TMPDIR}/zip.log
    
    superchunk=$(ls | grep chunk | grep super | sort)
    if [[ $(echo "$superchunk" | grep "sparsechunk") ]]; then
        "${SIMG2IMG}" $(echo "$superchunk" | tr '\n' ' ') super.img.raw 2>/dev/null
        rm -rf *super*chunk*
    fi
    
    superimage_extract || exit 1
}

# Process split super image
process_split_super_image() {
    echo "Super image detected"
    if [[ -f "${FILEPATH}" ]]; then
        foundsupers=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep "super.*img")
        ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundsupers}" dummypartition 2>/dev/null >> "${TMPDIR}"/zip.log
    fi
    
    # Handle split super images
    splitsupers=$(ls | grep -oP "super.[0-9].+.img")
    if [[ ! -z "${splitsupers}" ]]; then
        echo "Creating super.img.raw..."
        "${SIMG2IMG}" ${splitsupers} super.img.raw 2>/dev/null
        rm -rf -- ${splitsupers}
    fi
    
    # Handle super chunks
    superchunk=$(find . -maxdepth 1 -type f -name "*super*chunk*" | cut -d'/' -f'2-' | sort)
    if echo "${superchunk}" | grep -q "sparsechunk"; then
        echo "Creating super.img.raw..."
        "${SIMG2IMG}" ${superchunk} super.img.raw 2>/dev/null
        rm -rf -- *super*chunk*
    fi
    
    superimage_extract || exit 1
}

# Process AP tarmd5
process_ap_tarmd5() {
    echo "AP tarmd5 detected"
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} e -y "${FILEPATH}" 2>/dev/null >> "${TMPDIR}"/zip.log
    
    echo "Extracting images..."
    for i in $(ls *.tar.md5); do
        tar -xf "${i}" || exit 1
        rm -fv "${i}" || exit 1
        echo "Extracted ${i}"
    done
    
    # Extract lz4 archives if present
    [[ $(ls *.lz4 2>/dev/null) ]] && {
        echo "Extracting lz4 archives..."
        for f in $(ls *.lz4); do
            lz4 -dc ${f} > "${f/.lz4/}" || exit 1
            rm -fv ${f} || exit 1
            echo "Extracted ${f}"
        done
    }
    
    # Rename Samsung ext4 image files
    for samsung_ext4_img_files in $(find -maxdepth 1 -type f -name \*.ext4 -printf '%P\n'); do
        mv -v $samsung_ext4_img_files "${samsung_ext4_img_files%%.ext4}"
    done
    
    # Process super image if found
    if [[ -f super.img ]]; then
        superimage_extract || exit 1    
    fi
    
    if [[ ! -f system.img ]]; then
        echo "Extract failed"
        rm -rf "${TMPDIR}" && exit 1
    fi
}

# Process AB OTA payload
process_ab_ota_payload() {
    echo "AB OTA payload detected"
    ${PAYLOAD_EXTRACTOR} -c "$(nproc --all)" -o "${TMPDIR}" "${FILEPATH}" >/dev/null
}

# Process archived firmware
process_archive() {
    echo "Rar/Zip/7Zip/Tar archived firmware detected"
    if [[ -f "${FILEPATH}" ]]; then
        mkdir -p "${TMPDIR}"/"${UNZIP_DIR}" 2>/dev/null
        ${BIN_7ZZ} e -y "${FILEPATH}" -o"${TMPDIR}"/"${UNZIP_DIR}" >> "${TMPDIR}"/zip.log
        for f in "${TMPDIR}"/"${UNZIP_DIR}"/*; do 
            detox -r "${f}" 2>/dev/null
        done
    fi
    
    # Find large archives inside the extracted content
    zip_list=$(find ./"${UNZIP_DIR}" -type f -size +300M \( -name "*.rar" -o -name "*.zip" -o -name "*.7z" -o -name "*.tar" \) | cut -d'/' -f'2-' | sort)
    
    # Process each archive
    mkdir -p "${INPUTDIR}" 2>/dev/null
    rm -rf "${INPUTDIR:?}"/* 2>/dev/null
    for file in ${zip_list}; do
        mv "${TMPDIR}"/"${file}" "${INPUTDIR}"/
        rm -rf "${TMPDIR:?}"/*
        cd "${PROJECT_DIR}"/ || exit
        (bash "${0}" "${INPUTDIR}"/"${file}") || exit 1
        exit
    done
    
    rm -rf "${TMPDIR:?}"/"${UNZIP_DIR}"
}

# Process Huawei UPDATE.APP
process_huawei_update_app() {
    echo "Huawei UPDATE.APP detected"
    [[ -f "${FILEPATH}" ]] && ${BIN_7ZZ} x "${FILEPATH}" UPDATE.APP 2>/dev/null >> "${TMPDIR}"/zip.log
    find "${TMPDIR}" -type f -name "UPDATE.APP" -exec mv {} . \;
    
    # Extract partitions
    python3 "${SPLITUAPP}" -f "UPDATE.APP" -l super preas preavs || (
    for partition in ${PARTITIONS}; do
        python3 "${SPLITUAPP}" -f "UPDATE.APP" -l "${partition/.img/}" || echo "${partition} not found in UPDATE.APP"
    done )
    
    # Move extracted images
    find output/ -type f -name "*.img" -exec mv {} . \;
    
    # Process super image if found
    if [[ -f super.img ]]; then
        echo "Creating super.img.raw..."
        "${SIMG2IMG}" super.img super_* super.img.raw 2>/dev/null
        [[ ! -s super.img.raw && -f super.img ]] && mv super.img super.img.raw
    fi
    
    superimage_extract || exit 1
}

# Process Rockchip firmware
process_rockchip() {
    echo "Rockchip detected"
    ${RK_EXTRACT} -unpack "${FILEPATH}" ${TMPDIR}
    ${AFPTOOL_EXTRACT} -unpack ${TMPDIR}/firmware.img ${TMPDIR}
    
    # Process super image if found
    [ -f ${TMPDIR}/Image/super.img ] && {
        mv ${TMPDIR}/Image/super.img ${TMPDIR}/super.img
        cd ${TMPDIR}
        superimage_extract || exit 1
        cd -
    }
    
    # Move partitions to output
    for partition in $PARTITIONS; do
        [[ -e "${TMPDIR}/Image/${partition}.img" ]] && mv "${TMPDIR}/Image/${partition}.img" "${OUTDIR}/${partition}.img"
        [[ -e "${TMPDIR}/${partition}.img" ]] && mv "${TMPDIR}/${partition}.img" "${OUTDIR}/${partition}.img"
    done
}

# ------------------------------
# Post-processing functions
# ------------------------------

# Process PAC archive separately
process_pac_archive() {
    if [[ "${EXTENSION}" == "pac" ]]; then
        echo "PAC archive detected."
        python3 ${PACEXTRACTOR} ${FILEPATH} $(pwd)
        superimage_extract || exit 1
        exit
    fi
}

# Process other partitions from TMPDIR
process_other_partitions() {
    for otherpartition in ${OTHERPARTITIONS}; do
        filename=${otherpartition%:*} && outname=${otherpartition#*:}
        output=$(ls -- "${filename}"* 2>/dev/null)
        if [[ -f "${output}" ]]; then
            echo "${output} detected for ${outname}"
            [[ ! -e "${TMPDIR}"/"${outname}".img ]] && mv "${output}" "${TMPDIR}"/"${outname}".img
            "${SIMG2IMG}" "${TMPDIR}"/"${outname}".img "${OUTDIR}"/"${outname}".img 2>/dev/null
            [[ ! -s "${OUTDIR}"/"${outname}".img && -f "${TMPDIR}"/"${outname}".img ]] && mv "${outname}".img "${OUTDIR}"/"${outname}".img
        fi
    done
}

# Process all partitions from TMPDIR
process_all_partitions() {
    for partition in ${PARTITIONS}; do
        if [[ ! -f "${partition}".img ]]; then
            foundpart=$(${BIN_7ZZ} l -ba "${FILEPATH}" | gawk '{print $NF}' | grep "${partition}.img" 2>/dev/null)
            ${BIN_7ZZ} e -y -- "${FILEPATH}" "${foundpart}" */"${foundpart}" 2>/dev/null >> "${TMPDIR}"/zip.log
        fi
        
        # Convert sparse images
        [[ -f "${partition}".img ]] && "${SIMG2IMG}" "${partition}".img "${OUTDIR}"/"${partition}".img 2>/dev/null
        [[ ! -s "${OUTDIR}"/"${partition}".img && -f "${TMPDIR}"/"${partition}".img ]] && mv "${TMPDIR}"/"${partition}".img "${OUTDIR}"/"${partition}".img
        
        # Handle special EXT4 partitions with headers
        if [[ "${EXT4PARTITIONS}" =~ (^|[[:space:]])"${partition}"($|[[:space:]]) && -f "${OUTDIR}"/"${partition}".img ]]; then
            MAGIC=$(head -c12 "${OUTDIR}"/"${partition}".img | tr -d '\0')
            offset=$(LANG=C grep -aobP -m1 '\x53\xEF' "${OUTDIR}"/"${partition}".img | head -1 | gawk '{print $1 - 1080}')
            
            if echo "${MAGIC}" | grep -q "MOTO"; then
                [[ "$offset" == 128055 ]] && offset=131072
                echo "MOTO header detected on ${partition} at offset ${offset}"
            elif echo "${MAGIC}" | grep -q "ASUS"; then
                echo "ASUS header detected on ${partition} at offset ${offset}"
            else
                offset=0
            fi
            
            # Remove header if needed
            if [[ ! "${offset}" == "0" ]]; then
                dd if="${OUTDIR}"/"${partition}".img of="${OUTDIR}"/"${partition}".img-2 ibs=$offset skip=1 2>/dev/null
                mv -f "${OUTDIR}"/"${partition}".img-2 "${OUTDIR}"/"${partition}".img
            fi
        fi
        
        # Remove empty partition images
        [[ ! -s "${OUTDIR}"/"${partition}".img && -f "${OUTDIR}"/"${partition}".img ]] && rm "${OUTDIR}"/"${partition}".img
    done
}

# ------------------------------
# Extract boot-related partitions
# ------------------------------

# Extract boot.img
extract_boot() {
    if [[ -f "${OUTDIR}"/boot.img ]]; then
        # Extract device tree blobs
        mkdir -p "${OUTDIR}"/bootimg "${OUTDIR}"/bootdts 2>/dev/null
        uvx -q extract-dtb "${OUTDIR}"/boot.img -o "${OUTDIR}"/bootimg >/dev/null
        find "${OUTDIR}"/bootimg -name '*.dtb' -type f | gawk -F'/' '{print $NF}' | while read -r i; do 
            "${DTC}" -q -s -f -I dtb -O dts -o bootdts/"${i/\.dtb/.dts}" bootimg/"${i}"
        done 2>/dev/null
        
        # Unpack boot image
        bash "${UNPACKBOOT}" "${OUTDIR}"/boot.img "${OUTDIR}"/boot 2>/dev/null
        echo "Boot extracted"
        
        # Extract kernel config
        mkdir -p "${OUTDIR}"/bootRE
        bash "${EXTRACT_IKCONFIG}" "${OUTDIR}"/boot.img > "${OUTDIR}"/bootRE/ikconfig 2> /dev/null
        [[ ! -s "${OUTDIR}"/bootRE/ikconfig ]] && rm -f "${OUTDIR}"/bootRE/ikconfig 2>/dev/null
        
        # Generate vmlinux ELF and kallsyms
        if [[ ! -f "${OUTDIR}"/vendor_boot.img ]]; then
            python3 "${KALLSYMS_FINDER}" "${OUTDIR}"/boot.img > "${OUTDIR}"/bootRE/boot_kallsyms.txt 2>/dev/null
            echo "boot_kallsyms.txt generated"
        else
            python3 "${KALLSYMS_FINDER}" "${OUTDIR}"/boot/kernel > "${OUTDIR}"/bootRE/kernel_kallsyms.txt 2>/dev/null
            echo "kernel_kallsyms.txt generated"
        fi
        
        python3 "${VMLINUX2ELF}" "${OUTDIR}"/boot.img "${OUTDIR}"/bootRE/boot.elf >/dev/null 2>&1
        echo "boot.elf generated"
        
        # Process boot dtb if present
        [[ -f "${OUTDIR}"/boot/dtb.img ]] && {
            mkdir -p "${OUTDIR}"/dtbimg 2>/dev/null
            uvx -q extract-dtb "${OUTDIR}"/boot/dtb.img -o "${OUTDIR}"/dtbimg >/dev/null
        }
    fi
}

# Extract vendor_boot.img
extract_vendor_boot() {
    if [[ -f "${OUTDIR}"/vendor_boot.img ]]; then
        # Extract device tree blobs
        mkdir -p "${OUTDIR}"/vendor_bootimg "${OUTDIR}"/vendor_bootdts 2>/dev/null
        uvx -q extract-dtb "${OUTDIR}"/vendor_boot.img -o "${OUTDIR}"/vendor_bootimg >/dev/null
        find "${OUTDIR}"/vendor_bootimg -name '*.dtb' -type f | gawk -F'/' '{print $NF}' | while read -r i; do 
            "${DTC}" -q -s -f -I dtb -O dts -o vendor_bootdts/"${i/\.dtb/.dts}" vendor_bootimg/"${i}"
        done 2>/dev/null
        
        # Unpack vendor boot image
        bash "${UNPACKBOOT}" "${OUTDIR}"/vendor_boot.img "${OUTDIR}"/vendor_boot 2>/dev/null
        echo "Vendor boot extracted"
        
        # Generate vendor boot ELF
        mkdir -p "${OUTDIR}"/vendor_bootRE
        python3 "${VMLINUX2ELF}" "${OUTDIR}"/vendor_boot.img "${OUTDIR}"/vendor_bootRE/vendor_boot.elf >/dev/null 2>&1
        echo "vendor_boot.elf generated"
        
        # Process vendor boot dtb if present
        [[ -f "${OUTDIR}"/vendor_boot/dtb.img ]] && {
            mkdir -p "${OUTDIR}"/vendor_dtbimg 2>/dev/null
            uvx -q extract-dtb "${OUTDIR}"/vendor_boot/dtb.img -o "${OUTDIR}"/vendor_dtbimg >/dev/null
        }
    fi
}

# Extract recovery.img
extract_recovery() {
    if [[ -f "${OUTDIR}"/recovery.img ]]; then
        bash "${UNPACKBOOT}" "${OUTDIR}"/recovery.img "${OUTDIR}"/recovery 2>/dev/null
        echo "Recovery extracted"
    fi
}

# Extract dtbo
extract_dtbo() {
    if [[ -f "${OUTDIR}"/dtbo.img ]]; then
        mkdir -p "${OUTDIR}"/dtbo "${OUTDIR}"/dtbodts 2>/dev/null
        uvx -q extract-dtb "${OUTDIR}"/dtbo.img -o "${OUTDIR}"/dtbo >/dev/null
        find "${OUTDIR}"/dtbo -name '*.dtb' -type f | gawk -F'/' '{print $NF}' | while read -r i; do 
            "${DTC}" -q -s -f -I dtb -O dts -o dtbodts/"${i/\.dtb/.dts}" dtbo/"${i}"
        done 2>/dev/null
        echo "DTBO extracted"
    fi
}

# ------------------------------
# Extract system partitions
# ------------------------------
extract_partitions() {
    for p in $PARTITIONS; do
        if ! echo "${p}" | grep -q "boot\|recovery\|dtbo\|vendor_boot\|tz"; then
            if [[ -e "$p.img" ]]; then
                mkdir "$p" 2> /dev/null || rm -rf "${p:?}"/*
                echo "Extracting $p partition..."
                ${BIN_7ZZ} x -snld "$p".img -y -o"$p"/ > /dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    rm "$p".img > /dev/null 2>&1
                else
                    # Try EROFS extraction for unsupported filesystems
                    echo "Extraction failed by 7z"
                    if [ -f $p.img ] && [ $p != "modem" ]; then
                        echo "Trying fsck.erofs for $p partition"
                        rm -rf "${p}"/*
                        "${FSCK_EROFS}" --extract="$p" "$p".img
                        
                        if [ $? -eq 0 ]; then
                            rm -fv "$p".img > /dev/null 2>&1
                        else
                            echo "Trying mount loop for $p partition"
                            sudo mount -o loop -t auto "$p".img "$p"
                            mkdir "${p}_"
                            sudo cp -rf "${p}/"* "${p}_"
                            sudo umount "${p}"
                            sudo cp -rf "${p}_/"* "${p}"
                            sudo rm -rf "${p}_"
                            sudo chown -R "$(whoami)" "${p}"/*
                            chmod -R u+rwX "${p}"/*
                            
                            if [ $? -eq 0 ]; then
                                rm -fv "$p".img > /dev/null 2>&1
                            else
                                echo "Couldn't extract $p partition. It might use an unsupported filesystem."
                                echo "For EROFS: make sure you're using Linux 5.4+ kernel."
                                echo "For F2FS: make sure you're using Linux 5.15+ kernel."
                            fi
                        fi
                    fi
                fi
            fi
        fi
    done
}

# Remove unnecessary image leftovers
cleanup_images() {
    for q in *.img; do
        if ! echo "${q}" | grep -q "boot\|recovery\|dtbo\|tz"; then
            rm -f "${q}" 2>/dev/null
        fi
    done
}

# Extract Oppo/Realme Euclid images
extract_euclid_images() {
    for dir in "vendor/euclid" "system/system/euclid"; do
        if [[ -d "${dir}" ]]; then
            pushd "${dir}" || exit 1
            for f in *.img; do
                [[ -f "${f}" ]] || continue
                ${BIN_7ZZ} x "${f}" -o"${f/.img/}"
                rm -f "${f}"
            done
            popd || exit 1
        fi
    done
}

# ------------------------------
# Generate device information
# ------------------------------

# Generate board-info.txt
generate_board_info() {
    find "${OUTDIR}"/modem -type f -exec strings {} \; 2>/dev/null | grep "QC_IMAGE_VERSION_STRING=MPSS." | sed "s|QC_IMAGE_VERSION_STRING=MPSS.||g" | cut -c 4- | sed -e 's/^/require version-baseband=/' > "${TMPDIR}"/board-info.txt
    find "${OUTDIR}"/tz* -type f -exec strings {} \; 2>/dev/null | grep "QC_IMAGE_VERSION_STRING" | sed "s|QC_IMAGE_VERSION_STRING|require version-trustzone|g" >> "${TMPDIR}"/board-info.txt
    
    if [ -e "${OUTDIR}"/vendor/build.prop ]; then
        strings "${OUTDIR}"/vendor/build.prop | grep "ro.vendor.build.date.utc" | sed "s|ro.vendor.build.date.utc|require version-vendor|g" >> "${TMPDIR}"/board-info.txt
    fi
    
    sort -u < "${TMPDIR}"/board-info.txt > "${OUTDIR}"/board-info.txt
}

# Extract device properties
extract_device_properties() {
    # Check if build.prop exists
    [[ $(find "$(pwd)"/system "$(pwd)"/system/system "$(pwd)"/vendor "$(pwd)"/*product -maxdepth 1 -type f -name "build*.prop" 2>/dev/null | sort -u | gawk '{print $NF}') ]] || { 
        echo "No system/vendor/product build.prop found, pushing incomplete dump" 
        return 1
    }
    
    # Extract device properties from build.prop files
    flavor=$(grep -m1 -oP "(?<=^ro.build.flavor=).*" -hs {system,system/system,vendor}/build*.prop)
    [[ -z "${flavor}" ]] && flavor=$(grep -m1 -oP "(?<=^ro.vendor.build.flavor=).*" -hs vendor/build*.prop)
    [[ -z "${flavor}" ]] && flavor=$(grep -m1 -oP "(?<=^ro.system.build.flavor=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${flavor}" ]] && flavor=$(grep -m1 -oP "(?<=^ro.build.type=).*" -hs {system,system/system}/build*.prop)
    
    release=$(grep -m1 -oP "(?<=^ro.build.version.release=).*" -hs {system,system/system,vendor}/build*.prop)
    [[ -z "${release}" ]] && release=$(grep -m1 -oP "(?<=^ro.vendor.build.version.release=).*" -hs vendor/build*.prop)
    [[ -z "${release}" ]] && release=$(grep -m1 -oP "(?<=^ro.system.build.version.release=).*" -hs {system,system/system}/build*.prop)
    
    id=$(grep -m1 -oP "(?<=^ro.build.id=).*" -hs {system,system/system,vendor}/build*.prop)
    [[ -z "${id}" ]] && id=$(grep -m1 -oP "(?<=^ro.vendor.build.id=).*" -hs vendor/build*.prop)
    [[ -z "${id}" ]] && id=$(grep -m1 -oP "(?<=^ro.system.build.id=).*" -hs {system,system/system}/build*.prop)
    
    tags=$(grep -m1 -oP "(?<=^ro.build.tags=).*" -hs {system,system/system,vendor}/build*.prop)
    [[ -z "${tags}" ]] && tags=$(grep -m1 -oP "(?<=^ro.vendor.build.tags=).*" -hs vendor/build*.prop)
    [[ -z "${tags}" ]] && tags=$(grep -m1 -oP "(?<=^ro.system.build.tags=).*" -hs {system,system/system}/build*.prop)
    
    platform=$(grep -m1 -oP "(?<=^ro.board.platform=).*" -hs {system,system/system,vendor}/build*.prop | head -1)
    [[ -z "${platform}" ]] && platform=$(grep -m1 -oP "(?<=^ro.vendor.board.platform=).*" -hs vendor/build*.prop)
    [[ -z "${platform}" ]] && platform=$(grep -m1 -oP "(?<=^ro.system.board.platform=).*" -hs {system,system/system}/build*.prop)
    
    # Extract manufacturer info
    manufacturer=$(grep -m1 -oP "(?<=^ro.product.manufacturer=).*" -hs {system,system/system,vendor}/build*.prop | head -1)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.brand.sub=).*" -hs system/system/euclid/my_product/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.vendor.product.manufacturer=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.vendor.manufacturer=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.system.product.manufacturer=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.system.manufacturer=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.odm.manufacturer=).*" -hs vendor/odm/etc/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.manufacturer=).*" -hs {oppo_product,my_product,product}/build*.prop | head -1)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.manufacturer=).*" -hs vendor/euclid/*/build.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.system.product.manufacturer=).*" -hs vendor/euclid/*/build.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.product.manufacturer=).*" -hs vendor/euclid/product/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.vendor.manufacturer=).*" -hs vendor/build*.prop)
    [[ -z "${manufacturer}" ]] && manufacturer=$(grep -m1 -oP "(?<=^ro.product.system.manufacturer=).*" -hs {system,system/system}/build*.prop)
    
    # Extract fingerprint
    fingerprint=$(grep -m1 -oP "(?<=^ro.build.fingerprint=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.vendor.build.fingerprint=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.system.build.fingerprint=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.product.build.fingerprint=).*" -hs product/build*.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.build.fingerprint=).*" -hs {oppo_product,my_product}/build*.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.system.build.fingerprint=).*" -hs my_product/build.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.vendor.build.fingerprint=).*" -hs my_product/build.prop)
    [[ -z "${fingerprint}" ]] && fingerprint=$(grep -m1 -oP "(?<=^ro.bootimage.build.fingerprint=).*" -hs vendor/build.prop)
    
    # Extract brand
    brand=$(grep -m1 -oP "(?<=^ro.product.brand=).*" -hs {system,system/system,vendor}/build*.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.brand.sub=).*" -hs system/system/euclid/my_product/build*.prop)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.vendor.brand=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.vendor.product.brand=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.system.brand=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${brand}" || ${brand} == "OPPO" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.system.brand=).*" -hs vendor/euclid/*/build.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.product.brand=).*" -hs vendor/euclid/product/build*.prop)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.odm.brand=).*" -hs vendor/odm/etc/build*.prop)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.brand=).*" -hs {oppo_product,my_product}/build*.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(grep -m1 -oP "(?<=^ro.product.brand=).*" -hs vendor/euclid/*/build.prop | head -1)
    [[ -z "${brand}" ]] && brand=$(echo "$fingerprint" | cut -d'/' -f1)
    
    # Extract codename
    codename=$(grep -m1 -oP "(?<=^ro.product.device=).*" -hs {vendor,system,system/system}/build*.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.vendor.product.device.oem=).*" -hs vendor/euclid/odm/build.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.vendor.device=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.vendor.product.device=).*" -hs vendor/build*.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.system.device=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.system.device=).*" -hs vendor/euclid/*/build.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.product.device=).*" -hs vendor/euclid/*/build.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.product.model=).*" -hs vendor/euclid/*/build.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.device=).*" -hs {oppo_product,my_product}/build*.prop | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.product.device=).*" -hs oppo_product/build*.prop)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.system.device=).*" -hs my_product/build*.prop)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.product.vendor.device=).*" -hs my_product/build*.prop)
    [[ -z "${codename}" ]] && codename=$(echo "$fingerprint" | cut -d'/' -f3 | cut -d':' -f1)
    [[ -z "${codename}" ]] && codename=$(grep -m1 -oP "(?<=^ro.build.fota.version=).*" -hs {system,system/system}/build*.prop | cut -d'-' -f1 | head -1)
    [[ -z "${codename}" ]] && codename=$(grep -oP "(?<=^ro.build.product=).*" -hs {vendor,system,system/system}/build*.prop | head -1)
    
    # Extract description
    description=$(grep -m1 -oP "(?<=^ro.build.description=).*" -hs {system,system/system,vendor}/build*.prop | head -1)
    [[ -z "${description}" ]] && description=$(grep -m1 -oP "(?<=^ro.vendor.build.description=).*" -hs vendor/build*.prop)
    [[ -z "${description}" ]] && description=$(grep -m1 -oP "(?<=^ro.system.build.description=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${description}" ]] && description=$(grep -m1 -oP "(?<=^ro.product.build.description=).*" -hs product/build.prop)
    [[ -z "${description}" ]] && description=$(grep -m1 -oP "(?<=^ro.product.build.description=).*" -hs product/build*.prop)
    
    # Extract incremental
    incremental=$(grep -m1 -oP "(?<=^ro.build.version.incremental=).*" -hs {system,system/system,vendor}/build*.prop | head -1)
    [[ -z "${incremental}" ]] && incremental=$(grep -m1 -oP "(?<=^ro.vendor.build.version.incremental=).*" -hs vendor/build*.prop)
    [[ -z "${incremental}" ]] && incremental=$(grep -m1 -oP "(?<=^ro.system.build.version.incremental=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${incremental}" ]] && incremental=$(grep -m1 -oP "(?<=^ro.build.version.incremental=).*" -hs my_product/build*.prop)
    [[ -z "${incremental}" ]] && incremental=$(grep -m1 -oP "(?<=^ro.system.build.version.incremental=).*" -hs my_product/build*.prop)
    [[ -z "${incremental}" ]] && incremental=$(grep -m1 -oP "(?<=^ro.vendor.build.version.incremental=).*" -hs my_product/build*.prop)
    
    # For Realme devices with empty incremental & fingerprint
    [[ -z "${incremental}" && "${brand}" =~ "realme" ]] && incremental=$(grep -m1 -oP "(?<=^ro.build.version.ota=).*" -hs {vendor/euclid/product,oppo_product}/build.prop | rev | cut -d'_' -f'1-2' | rev)
    [[ -z "${incremental}" && ! -z "${description}" ]] && incremental=$(echo "${description}" | cut -d' ' -f4)
    [[ -z "${description}" && ! -z "${incremental}" ]] && description="${flavor} ${release} ${id} ${incremental} ${tags}"
    [[ -z "${description}" && -z "${incremental}" ]] && description="${codename}"
    
    # Extract other properties
    abilist=$(grep -m1 -oP "(?<=^ro.product.cpu.abilist=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${abilist}" ]] && abilist=$(grep -m1 -oP "(?<=^ro.vendor.product.cpu.abilist=).*" -hs vendor/build*.prop)
    
    locale=$(grep -m1 -oP "(?<=^ro.product.locale=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${locale}" ]] && locale=undefined
    
    density=$(grep -m1 -oP "(?<=^ro.sf.lcd_density=).*" -hs {system,system/system}/build*.prop | head -1)
    [[ -z "${density}" ]] && density=undefined
    
    is_ab=$(grep -m1 -oP "(?<=^ro.build.ab_update=).*" -hs {system,system/system,vendor}/build*.prop)
    [[ -z "${is_ab}" ]] && is_ab="false"
    
    treble_support=$(grep -m1 -oP "(?<=^ro.treble.enabled=).*" -hs {system,system/system}/build*.prop)
    [[ -z "${treble_support}" ]] && treble_support="false"
    
    otaver=$(grep -m1 -oP "(?<=^ro.build.version.ota=).*" -hs {vendor/euclid/product,oppo_product,system,system/system}/build*.prop | head -1)
    [[ ! -z "${otaver}" && -z "${fingerprint}" ]] && branch=$(echo "${otaver}" | tr ' ' '-')
    [[ -z "${otaver}" ]] && otaver=$(grep -m1 -oP "(?<=^ro.build.fota.version=).*" -hs {system,system/system}/build*.prop | head -1)
    
    [[ -z "${branch}" ]] && branch=$(echo "${description}" | tr ' ' '-')
    
    # Set repository variables
    if [[ "$PUSH_TO_GITLAB" = true ]]; then
        rm -rf .github_token
        repo=$(printf "${brand}" | tr '[:upper:]' '[:lower:]' && echo -e "/${codename}")
    else
        rm -rf .gitlab_token
        repo=$(echo "${brand}"_"${codename}"_dump | tr '[:upper:]' '[:lower:]')
    fi
    
    # Sanitize variables for repo
    platform=$(echo "${platform}" | tr '[:upper:]' '[:lower:]' | tr -dc '[:print:]' | tr '_' '-' | cut -c 1-35)
    top_codename=$(echo "${codename}" | tr '[:upper:]' '[:lower:]' | tr -dc '[:print:]' | tr '_' '-' | cut -c 1-35)
    manufacturer=$(echo "${manufacturer}" | tr '[:upper:]' '[:lower:]' | tr -dc '[:print:]' | tr '_' '-' | cut -c 1-35)
    
    # Get kernel version
    [ -f "bootRE/ikconfig" ] && kernel_version=$(cat bootRE/ikconfig | grep "Kernel Configuration" | head -1 | awk '{print $3}')
    
    # Export variables for use in other functions
    export flavor release id tags platform manufacturer fingerprint brand codename description
    export incremental abilist locale density is_ab treble_support otaver branch repo
    export top_codename kernel_version
}

# Generate README.md
generate_readme() {
    # Generate the README file
    cat > "${OUTDIR}"/README.md << EOF
## ${description}
- Manufacturer: ${manufacturer}
- Platform: ${platform}
- Codename: ${codename}
- Brand: ${brand}
- Flavor: ${flavor}
- Release Version: ${release}
- Kernel Version: ${kernel_version}
- Id: ${id}
- Incremental: ${incremental}
- Tags: ${tags}
- CPU Abilist: ${abilist}
- A/B Device: ${is_ab}
- Treble Compatible: ${treble_support}
- Locale: ${locale}
- Screen Density: ${density}
EOF

    echo "README.md generated"
}

# ------------------------------
# Generate recovery trees
# ------------------------------
generate_twrp_tree() {
    twrpdtout="twrp-device-tree"
    
    # Determine which image to use for TWRP
    if [[ "$is_ab" = true ]]; then
        if [ -f recovery.img ]; then
            echo "Legacy A/B with recovery partition detected..."
            twrpimg="recovery.img"
        else
            twrpimg="boot.img"
        fi
    else
        twrpimg="recovery.img"
    fi
    
    # Generate TWRP device tree
    if [[ -f ${twrpimg} ]]; then
        mkdir -p $twrpdtout
        uvx -p 3.9 --from git+https://github.com/twrpdtgen/twrpdtgen@master twrpdtgen $twrpimg -o $twrpdtout
        if [[ "$?" = 0 ]]; then
            [[ ! -e "${OUTDIR}"/twrp-device-tree/README.md ]] && curl https://raw.githubusercontent.com/wiki/SebaUbuntu/TWRP-device-tree-generator/4.-Build-TWRP-from-source.md > ${twrpdtout}/README.md
        fi
    fi

    # Remove all .git directories from twrpdtout
    rm -rf $(find $twrpdtout -type d -name ".git")
}

# Generate LineageOS device tree
generate_lineage_tree() {
    if [[ "$treble_support" = true ]]; then
        aospdtout="aosp-device-tree"
        mkdir -p $aospdtout
        uvx -p 3.9 aospdtgen $OUTDIR -o $aospdtout

        # Remove all .git directories from aospdtout
        rm -rf $(find $aospdtout -type d -name ".git")
    fi
}

# ------------------------------
# Generate proprietary files lists
# ------------------------------

# Function to write sha1sum values for blobs
write_sha1sum() {
    # Usage: write_sha1sum <file> <destination_file>

    local SRC_FILE=$1
    local DST_FILE=$2

    # Temporary file
    local TMP_FILE=${SRC_FILE}.sha1sum.tmp
    
    # Get rid of all the blank lines and comments
    (cat ${SRC_FILE} | grep -v '^[[:space:]]*$' | grep -v "# ") > ${TMP_FILE}

    # Append the sha1sum of blobs in the destination file
    cp ${SRC_FILE} ${DST_FILE}
    cat ${TMP_FILE} | while read -r i; do {
        local BLOB=${i}

        # Remove leading "-" if present
        local BLOB_TOPDIR=$(echo ${BLOB} | cut -d / -f1)
        [ "${BLOB_TOPDIR:0:1}" = "-" ] && local BLOB=${BLOB_TOPDIR/-/}/${BLOB/${BLOB_TOPDIR}\//}

        # Handle different blob locations
        [ ! -e "${BLOB}" ] && {
            if [ -e "system/${BLOB}" ]; then
                local BLOB="system/${BLOB}"
            elif [ -e "system/system/${BLOB}" ]; then
                local BLOB="system/system/${BLOB}"
            fi
        }
        
        # Check if the blob was found before calculating its checksum
        if [ -e "${BLOB}" ]; then
            # Calculate SHA1 sum
            local SHA1=$(sha1sum "${BLOB}" | gawk '{print $1}')

            # Revert to original blob name for replacement
            local BLOB=${i}
            local ORG_EXP="${BLOB}"
            local FINAL_EXP="${BLOB}|${SHA1}"

            # Append the |sha1sum
            sed -i "s:${ORG_EXP}$:${FINAL_EXP}:g" "${DST_FILE}"
        else
            echo "--> WARNING: Blob not found, skipping SHA1 for: ${i}"
            # Remove the non-existent file from the final list
            sed -i "/^${i}$/d" "${DST_FILE}"
        fi
    }; done

    # Delete the temporary file
    rm ${TMP_FILE}
}

# Generate proprietary-files.txt
generate_proprietary_files() {
    echo "Generating proprietary-files.txt..."
    bash "${UTILSDIR}"/android_tools/tools/proprietary-files.sh "${OUTDIR}"/all_files.txt >/dev/null
    echo "# All blobs from ${description}, unless pinned" > "${OUTDIR}"/proprietary-files.txt
    cat "${UTILSDIR}"/android_tools/working/proprietary-files.txt >> "${OUTDIR}"/proprietary-files.txt

    # Generate proprietary-files.sha1
    echo "Generating proprietary-files.sha1..."
    echo "# All blobs are from \"${description}\" and are pinned with sha1sum values" > "${OUTDIR}"/proprietary-files.sha1
    write_sha1sum ${UTILSDIR}/android_tools/working/proprietary-files.{txt,sha1}
    cat "${UTILSDIR}"/android_tools/working/proprietary-files.sha1 >> "${OUTDIR}"/proprietary-files.sha1

    # Stash changes in android_tools
    git -C "${UTILSDIR}"/android_tools/ add --all
    git -C "${UTILSDIR}"/android_tools/ stash

    # Generate all_files.sha1
    echo "Generating all_files.sha1..."
    write_sha1sum "$OUTDIR"/all_files.{txt,sha1.tmp}
    (cat "$OUTDIR"/all_files.sha1.tmp | grep -v all_files.txt) > "$OUTDIR"/all_files.sha1
    rm -rf "$OUTDIR"/all_files.sha1.tmp
}

# ------------------------------
# Repository upload functions
# ------------------------------

# Commit and push to repository
commit_and_push() {
    local DIRS=(
        "system_ext"
        "product"
        "system_dlkm"
        "odm"
        "odm_dlkm"
        "vendor_dlkm"
        "vendor"
        "system"
    )

    git lfs install
    [ -e ".gitattributes" ] || find . -type f -not -path ".git/*" -size +100M -exec git lfs track {} \;
    [ -e ".gitattributes" ] && {
        git add ".gitattributes"
        git commit -sm "Setup Git LFS"
        git push -u origin "${branch}"
    }

    git add $(find -type f -name '*.apk')
    git commit -sm "Add apps for ${description}"
    git push -u origin "${branch}"

    for i in "${DIRS[@]}"; do
        [ -d "${i}" ] && git add "${i}"
        [ -d system/"${i}" ] && git add system/"${i}"
        [ -d system/system/"${i}" ] && git add system/system/"${i}"
        [ -d vendor/"${i}" ] && git add vendor/"${i}"

        git commit -sm "Add ${i} for ${description}"
        git push -u origin "${branch}"
    done

    git add .
    git commit -sm "Add extras for ${description}"
    git push -u origin "${branch}"
}

# Split large files for repository
split_files() {
    # usage: split_files <min_file_size> <part_size>
    # Files larger than ${1} will be split into ${2} parts as *.aa, *.ab, etc.
    mkdir -p "${TMPDIR}" 2>/dev/null
    find . -size +${1} | cut -d'/' -f'2-' >| "${TMPDIR}"/.largefiles
    if [[ -s "${TMPDIR}"/.largefiles ]]; then
        printf '#!/bin/bash\n\n' > join_split_files.sh
        while read -r l; do
            split -b ${2} "${l}" "${l}".
            rm -f "${l}" 2>/dev/null
            printf "cat %s.* 2>/dev/null >> %s\n" "${l}" "${l}" >> join_split_files.sh
            printf "rm -f %s.* 2>/dev/null\n" "${l}" >> join_split_files.sh
        done < "${TMPDIR}"/.largefiles
        chmod a+x join_split_files.sh 2>/dev/null
    fi
    rm -rf "${TMPDIR}" 2>/dev/null
}

# Push to GitHub
push_to_github() {
    if [[ -s "${PROJECT_DIR}"/.github_token ]]; then
        GITHUB_TOKEN=$(< "${PROJECT_DIR}"/.github_token)
        [[ -z "$(git config --get user.email)" ]] && git config user.email "dumper@github.com"
        [[ -z "$(git config --get user.name)" ]] && git config user.name "dumper"
        
        # Set GitHub organization
        if [[ -s "${PROJECT_DIR}"/.github_orgname ]]; then
            GIT_ORG=$(< "${PROJECT_DIR}"/.github_orgname)
        else
            GIT_USER="$(git config --get user.name)"
            GIT_ORG="${GIT_USER}"
        fi
        
        # Check if already dumped
        if curl -sf "https://raw.githubusercontent.com/${GIT_ORG}/${repo}/${branch}/all_files.txt" 2>/dev/null; then
            echo "Firmware already dumped!"
            echo "Go to https://github.com/${GIT_ORG}/${repo}/tree/${branch}"
            exit
        fi
        
        # Remove journal files
        find . -mindepth 2 -type d -name "\[SYS\]" -exec rm -rf {} \; 2>/dev/null
        
        # Split large files and prepare repository
        split_files 62M 47M
        echo -e "\nFinal repository should look like..."
        ls -lAog
        
        echo -e "\n\nStarting Git init..."
        git init
        git config --global http.postBuffer 524288000
        git checkout -b "${branch}" || { git checkout -b "${incremental}" && export branch="${incremental}"; }
        
        # Create .gitignore
        find . \( -name "*sensetime*" -o -name "*.lic" \) | cut -d'/' -f'2-' >| .gitignore
        [[ ! -s .gitignore ]] && rm .gitignore
        
        # Create GitHub repository
        if [[ "${GIT_ORG}" == "${GIT_USER}" ]]; then
            curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" -d '{"name": "'"${repo}"'", "description": "'"${description}"'"}' "https://api.github.com/user/repos" >/dev/null 2>&1
        else
            curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" -d '{ "name": "'"${repo}"'", "description": "'"${description}"'"}' "https://api.github.com/orgs/${GIT_ORG}/repos" >/dev/null 2>&1
        fi
        
        # Add repository topics
        curl -s -X PUT -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.mercy-preview+json" -d '{ "names": ["'"${platform}"'","'"${manufacturer}"'","'"${top_codename}"'","firmware","dump"] }' "https://api.github.com/repos/${GIT_ORG}/${repo}/topics" >/dev/null 2>&1
        
        # Commit and push
        echo -e "\nPushing to https://github.com/${GIT_ORG}/${repo}.git via HTTPS...\nBranch: ${branch}"
        sleep 1
        git remote add origin https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${repo}.git
        commit_and_push
        sleep 1
        
        # Send Telegram notification
        send_telegram_notification
    else
        push_to_gitlab
    fi
}

# Push to GitLab
push_to_gitlab() {
    if [[ -s "${PROJECT_DIR}"/.gitlab_token ]]; then
        # Set GitLab group/organization
        if [[ -s "${PROJECT_DIR}"/.gitlab_group ]]; then
            GIT_ORG=$(< "${PROJECT_DIR}"/.gitlab_group)
        else
            GIT_USER="$(git config --get user.name)"
            GIT_ORG="${GIT_USER}"
        fi

        # GitLab variables
        GITLAB_TOKEN=$(< "${PROJECT_DIR}"/.gitlab_token)
        if [ -f "${PROJECT_DIR}"/.gitlab_instance ]; then
            GITLAB_INSTANCE=$(< "${PROJECT_DIR}"/.gitlab_instance)
        else
            GITLAB_INSTANCE="gitlab.com"
        fi
        GITLAB_HOST="https://${GITLAB_INSTANCE}"

        # Check if already dumped
        if [[ $(curl -sL "${GITLAB_HOST}/${GIT_ORG}/${repo}/-/raw/${branch}/all_files.txt" | grep "all_files.txt") ]]; then
            echo "Firmware already dumped!"
            echo "Go to ${GITLAB_HOST}/${GIT_ORG}/${repo}/-/tree/${branch}"
            exit
        fi

        # Prepare repository
        find . -mindepth 2 -type d -name "\[SYS\]" -exec rm -rf {} \; 2>/dev/null
        split_files 62M 47M
        echo -e "\nFinal repository should look like..."
        ls -lAog
        
        echo -e "\n\nStarting Git init..."
        git init
        git config --global http.postBuffer 524288000
        git checkout -b "${branch}" || { git checkout -b "${incremental}" && export branch="${incremental}"; }
        
        # Create .gitignore
        find . \( -name "*sensetime*" -o -name "*.lic" \) | cut -d'/' -f'2-' >| .gitignore
        [[ ! -s .gitignore ]] && rm .gitignore
        
        # Set git user if not set
        [[ -z "$(git config --get user.email)" ]] && git config user.email "dumper@gitlab.com"
        [[ -z "$(git config --get user.name)" ]] && git config user.name "dumper"

        # Create GitLab subgroup
        GRP_ID=$(curl -s --request GET --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${GITLAB_HOST}/api/v4/groups/${GIT_ORG}" | jq -r '.id')
        curl --request POST \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        --header "Content-Type: application/json" \
        --data '{"name": "'"${brand}"'", "path": "'"$(echo ${brand} | tr [:upper:] [:lower:])"'", "visibility": "public", "parent_id": "'"${GRP_ID}"'"}' \
        "${GITLAB_HOST}/api/v4/groups/"
        echo ""

        # Get subgroup ID
        get_gitlab_subgrp_id "${brand}" /tmp/subgrp_id.txt
        SUBGRP_ID=$(< /tmp/subgrp_id.txt)

        # Create repository
        curl -s \
        --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        -X POST \
        "${GITLAB_HOST}/api/v4/projects?name=${codename}&namespace_id=${SUBGRP_ID}&visibility=public"

        # Get project ID
        get_gitlab_project_id "${codename}" "${SUBGRP_ID}" /tmp/proj_id.txt
        PROJECT_ID=$(< /tmp/proj_id.txt)

        # Delete temporary files
        rm -rf /tmp/{subgrp,subgrp_id,proj,proj_id}.txt

        # Set remote (using SSH for large repos)
        git remote add origin git@${GITLAB_INSTANCE}:${GIT_ORG}/${repo}.git

        # Ensure public visibility
        curl --request PUT --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" --url "${GITLAB_HOST}/api/v4/projects/${PROJECT_ID}" --data "visibility=public"
        echo ""

        # Push until successful
        while [[ ! $(curl -sL "${GITLAB_HOST}/${GIT_ORG}/${repo}/-/raw/${branch}/all_files.txt" | grep "all_files.txt") ]]; do
            echo -e "\nPushing to ${GITLAB_HOST}/${GIT_ORG}/${repo}.git via SSH...\nBranch: ${branch}"
            sleep 1
            commit_and_push
            sleep 1
        done

        # Update default branch
        curl --request PUT \
             --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
             --url "${GITLAB_HOST}/api/v4/projects/${PROJECT_ID}" \
             --data "default_branch=${branch}"
        echo ""

        # Send Telegram notification
        send_telegram_notification "${GITLAB_HOST}"
    else
        echo "Dumping done locally. No repository credentials found."
    fi
}

# Helper function for GitLab subgroup ID
get_gitlab_subgrp_id() {
    local SUBGRP=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    curl -s --request GET --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "${GITLAB_HOST}/api/v4/groups/${GIT_ORG}/subgroups" | jq -r .[] | jq -r .path,.id > /tmp/subgrp.txt
    local i
    for i in $(seq "$(cat /tmp/subgrp.txt | wc -l)"); do
        local TMP_I=$(cat /tmp/subgrp.txt | head -"$i" | tail -1)
        [[ "$TMP_I" == "$SUBGRP" ]] && cat /tmp/subgrp.txt | head -$(("$i"+1)) | tail -1 > "$2"
    done
}

# Helper function for GitLab project ID
get_gitlab_project_id() {
    local PROJ="$1"
    curl -s --request GET --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "${GITLAB_HOST}/api/v4/groups/$2/projects" | jq -r .[] | jq -r .path,.id > /tmp/proj.txt
    local i
    for i in $(seq "$(cat /tmp/proj.txt | wc -l)"); do
        local TMP_I=$(cat /tmp/proj.txt | head -"$i" | tail -1)
        [[ "$TMP_I" == "$PROJ" ]] && cat /tmp/proj.txt | head -$(("$i"+1)) | tail -1 > "$3"
    done
}

# Send Telegram notification
send_telegram_notification() {
    local host_url="${1:-https://github.com}"
    
    if [[ -s "${PROJECT_DIR}"/.tg_token ]]; then
        TG_TOKEN=$(< "${PROJECT_DIR}"/.tg_token)
        if [[ -s "${PROJECT_DIR}"/.tg_chat ]]; then
            CHAT_ID=$(< "${PROJECT_DIR}"/.tg_chat)
        else
            CHAT_ID="@DumperDumps"
        fi
        
        echo "Sending telegram notification..."
        printf "<b>Brand: %s</b>" "${brand}" >| "${OUTDIR}"/tg.html
        {
            printf "\n<b>Device: %s</b>" "${codename}"
            printf "\n<b>Platform: %s</b>" "${platform}"
            printf "\n<b>Android Version:</b> %s" "${release}"
            [ ! -z "${kernel_version}" ] && printf "\n<b>Kernel Version:</b> %s" "${kernel_version}"
            printf "\n<b>Fingerprint:</b> %s" "${fingerprint}"
            printf "\n<a href=\"${host_url}/%s/%s/tree/%s/\">Repository Link</a>" "${GIT_ORG}" "${repo}" "${branch}"
        } >> "${OUTDIR}"/tg.html
        
        TEXT=$(< "${OUTDIR}"/tg.html)
        rm -rf "${OUTDIR}"/tg.html
        
        curl -s "https://api.telegram.org/bot${TG_TOKEN}/sendmessage" --data "text=${TEXT}&chat_id=${CHAT_ID}&parse_mode=HTML&disable_web_page_preview=True" || echo "Telegram notification sending error."
    fi
}

# ------------------------------
# Main function
# ------------------------------
main() {
    # Setup environment and display banner
    setup_environment
    show_banner
    
    # Validate input
    validate_input "$@"
    
    # Setup tools
    setup_tools
    
    # Process input
    process_input "$1"
    
    echo "Extracting firmware to: ${OUTDIR}"
    
    # Process firmware
    process_firmware
    
    # Handle PAC archive
    process_pac_archive
    
    # Process partitions
    cd "${OUTDIR}"/ || exit
    mv "${TMPDIR}"/*.img "${OUTDIR}"/ 2>/dev/null
    rm -rf "${TMPDIR:?}"/*
    
    # Extract boot-related partitions
    extract_boot
    extract_vendor_boot
    extract_recovery
    extract_dtbo
    
    # Extract system partitions
    extract_partitions
    
    # Cleanup
    cleanup_images
    
    # Extract Euclid images
    extract_euclid_images
    
    # Generate board-info.txt
    generate_board_info
    
    # Extract device properties
    extract_device_properties
    
    # Generate README.md
    generate_readme
    
    # Generate recovery trees
    generate_twrp_tree
    generate_lineage_tree
    
    # Generate file list
    find "$OUTDIR" -type f -printf '%P\n' | sort | grep -v ".git/" > "$OUTDIR"/all_files.txt
    
    # Generate proprietary files
    generate_proprietary_files
    
    # Regenerate all_files.txt
    find "$OUTDIR" -type f -printf '%P\n' | sort | grep -v ".git/" > "$OUTDIR"/all_files.txt
    
    # Set permissions
    chown "$(whoami)" ./* -R
    chmod -R u+rwX ./*
    
    # Push to repository
    push_to_github
}

# Run main function with all arguments
main "$@"
