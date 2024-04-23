#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Source configuration variables
source config.env

# Set git config
git config --global user.email "${git_email}"
git config --global user.name "${git_name}"

# Define main directory
main_dir="$(readlink -f -- $(pwd))/rom"
if [ -d "${main_dir}" ]; then
    echo "[!] Main directory already exists"
    cd "${main_dir}" || exit 1
else
    mkdir -p "${main_dir}"
    cd "${main_dir}" || exit 1
fi

# Function to send Telegram messages
send_msg() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Function to clone repositories
clone_repo() {
    local repo_path="${1}"
    local clone_url="${2}"
    local repo_name="${3}"
    local branch="${4:-master}"
    local depth="${5}"  # Depth value provided as argument, if any
    if [ -d "${repo_path}" ]; then
        echo "[!] ${repo_name} already cloned"
    else
        echo "[*] Cloning ${repo_name}"
        if [ -n "$depth" ]; then
            git clone --depth "${depth}" -b "${branch}" "${clone_url}" "${repo_path}"
        else
            git clone -b "${branch}" "${clone_url}" "${repo_path}"
        fi
    fi
}

# Function to update repositories
update_repo() {
    local repo_path="${1}"
    local branch="${2}"
    local repo_name="${3}"
    if [ -d "${repo_path}" ]; then
        echo "[*] Updating ${repo_name}"
        cd "${repo_path}"
        if git fetch origin "${branch}" 2>/dev/null; then
            git pull origin "${branch}" || echo "[!] Failed to update ${repo_name}"
        else
            echo "[!] Branch ${branch} doesn't exist on the remote repository"
        fi
        cd "${main_dir}"
    else
        echo "[!] ${repo_name} not found"
    fi
}

# Function to upload ROM
upload_rom() {
    if [ "${PD_UPLOAD}" = "true" ]; then
        cd "${main_dir}"
        # Set the target directory
        export TARGET_DIR="${main_dir}/out/target/product/${device_codename}"
        # ROM name to be used in the python script to find the zip
        export ROM_NAME="astera"
        zip_path="$(python3 ../get_rom_zip.py)"
        if [ -f "${zip_path}" ]; then
            echo "[*] Uploading the ROM"
            export FILE_ID="$(curl -sT "${zip_path}" https://pixeldrain.com/api/file/ | grep -o '"id":"[^"]*' | awk -F ':"' '{print $2}')"
            echo "[*] Download the ROM at: https://pixeldrain.com/u/${FILE_ID}"
        else
            echo "[!] No ROM to upload"
        fi
    fi
}

# Function to apply patches
apply_patches() {
    if [ -f "../patches.sh" ]; then
        echo "[*] Applying patches"
        cp ../patches.sh .
        chmod +x patches.sh
        ./patches.sh
        rm patches.sh
    else
        echo "[!] No patches to apply"
    fi
}

# Create the build directory if not already initialized
if [ -f ".repo/manifest.xml" ]; then
    echo "[!] Repo already initialized"
    cd "${main_dir}" || exit 1
else
    mkdir -p "${main_dir}"
    cd "${main_dir}" || exit 1
    # Init the repo
    echo "[*] Initializing the repo"
    repo init -u "${repo}" -b "${repo_branch}" ${init_args}
fi

# Sync the repo if initialized
if [ -d ".repo" ]; then
    if [ "${should_skip_sync}" = "1" ]; then
        echo "[!] Skipping sync"
    else
        echo "[*] Syncing the repo"
        repo sync ${sync_args}
        apply_patches
    fi
else
    echo "[!] Repo not initialized"
    exit 1
fi

# Clone repositories
clone_repo "${device_tree_path}" "${device_tree_clone}" "Device tree" "${device_tree_branch}"
clone_repo "${sepolicy_tree_path}" "${sepolicy_tree_clone}" "Sepolicy tree" "${sepolicy_tree_branch}"
clone_repo "${vendor_tree_path}" "${vendor_tree_clone}" "Vendor tree" "${vendor_tree_branch}" 15
clone_repo "${ims_vendor_tree_path}" "${ims_vendor_tree_clone}" "IMS Vendor tree" "${ims_vendor_tree_branch}" 1
clone_repo "${fw_vendor_tree_path}" "${fw_vendor_tree_clone}" "Firmware Vendor tree" "${fw_vendor_tree_branch}" 1
clone_repo "${kernel_tree_path}" "${kernel_tree_clone}" "Kernel" "${kernel_tree_branch}" 250

# Clone and update extra repos
if [ -n "${extra_repos_clone}" ]; then
    IFS='|' read -r -a extra_repos_clone <<< "${extra_repos_clone}"
    IFS='|' read -r -a extra_repos_path <<< "${extra_repos_path}"
    IFS='|' read -r -a extra_repos_branch <<< "${extra_repos_branch}"
    IFS='|' read -r -a extra_repos_args <<< "${extra_repos_args}"

    for index in "${!extra_repos_clone[@]}"; do
        repo_path="${main_dir}/${extra_repos_path[index]}"
        clone_repo "${repo_path}" "${extra_repos_clone[index]}" "Extra Repo ${extra_repos_path[index]}" "${extra_repos_branch[index]}" ${extra_repos_args[index]}
        if [ "${should_update_trees}" = "1" ]; then
            update_repo "${repo_path}" "${extra_repos_branch[index]}" "Extra Repo ${extra_repos_path[index]}"
        fi
    done
else
    echo "[!] No extra repos to clone"
fi

# Update repositories if needed
if [ "${should_update_trees}" = "1" ]; then
    update_repo "${device_tree_path}" "${device_tree_branch}" "Device repos"
    update_repo "${sepolicy_tree_path}" "${sepolicy_tree_branch}" "Sepolicy repos"
    update_repo "${vendor_tree_path}" "${vendor_tree_branch}" "Vendor repos"
    update_repo "${ims_vendor_tree_path}" "${ims_vendor_tree_branch}" "IMS Vendor repos"
    update_repo "${fw_vendor_tree_path}" "${fw_vendor_tree_branch}" "Firmware Vendor repos"
    update_repo "${kernel_tree_path}" "${kernel_tree_branch}" "Kernel repos"
fi

# Clean the out directory if needed
if [ "${clean_out}" = "1" ]; then
    echo "[*] Cleaning the out directory"
    cd "${main_dir}"
    rm -rf out/
fi

# Clone and set Telegram stuff
if [ ! -f "./Telegram/telegram" ]; then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi
TELEGRAM=./Telegram/telegram

# Send a message to the Telegram channel
if [ "${TELEGRAM_TOKEN}" != "" ] && [ "${TELEGRAM_CHAT}" != "" ]; then
    repo_branch=$(git rev-parse --abbrev-ref HEAD)
    MSG="Build for ${device_codename} started
- Commit: $(git log --pretty=format:'%h - %s' -n 1)
- By: ${git_name}"
    send_msg "${MSG}"
fi

# Build the ROM
echo "[*] Starting the build"
echo "[*] Building ${device_codename}"
cd "${main_dir}"
. build/envsetup.sh

# Do an installclean if needed
if [ "${installclean}" = "1" ]; then
    echo "[*] Running installclean"
    ${lunch_cmd}
    make installclean
    ${make_cmd} || { echo "[!] Build failed"; send_msg "Build failed for ${device_codename} - Log: https://ci.erensprojects.me/job/${JOB_NAME}/ws/rom/out/error.log"; exit 1; }
else
    ${lunch_cmd}
    ${make_cmd} || { echo "[!] Build failed"; send_msg "Build failed for ${device_codename} - Log: https://ci.erensprojects.me/job/${JOB_NAME}/ws/rom/out/error.log"; exit 1; }
fi

# If the build is successful, upload ROM
echo "[*] Build completed successfully"
upload_rom

# Send a message to the Telegram channel
if [ "${TELEGRAM_TOKEN}" != "" ] && [ "${TELEGRAM_CHAT}" != "" ]; then
    if [ -z "${FILE_ID}" ]; then
        repo_branch=$(git rev-parse --abbrev-ref HEAD)
        MSG="Build for ${device_codename} finished
- Download the ROM at: https://ci.erensprojects.me/job/${JOB_NAME}/ws/rom/out/target/product/${device_codename}/${zip_path}
- By: ${git_name}"
        send_msg "${MSG}"
    else
        repo_branch=$(git rev-parse --abbrev-ref HEAD)
        MSG="Build for ${device_codename} finished
- Download the ROM at: https://pixeldrain.com/u/${FILE_ID}
- By: ${git_name}"
        send_msg "${MSG}"
    fi
fi

exit 0
