#!/usr/bin/env bash

source config.env
main_dir="$(readlink -f -- $(pwd))/rom"

# Set git config
git config --global user.email "${git_email}"
git config --global user.name "${git_name}"

# Create the build directory
if [ -f rom/.repo/manifest.xml ]; then
    echo "[!] Repo already initialized"
    cd ${main_dir}
else
    mkdir -p ${main_dir}
    cd ${main_dir}
    # Init the repo
    echo "[*] Initializing the repo"
    repo init -u ${repo} -b ${repo_branch} --depth=10
fi

# Sync the repo
if [ -d .repo ]; then
    if [ "${should_skip_sync}" = "1" ]; then
        echo "[!] Skipping sync"
    else
        echo "[*] Syncing the repo"
        repo sync ${sync_args}
    fi
else
    echo "[!] Repo not initialized"
    exit 1
fi

# Clone the device tree
if [ -d "${device_tree_path}" ]; then
    echo "[!] Device tree already cloned"
else
    echo "[*] Cloning the device tree"
    git clone ${device_tree_clone}
fi

# Clone the sepolicy tree
if [ -d "${sepolicy_tree_path}" ]; then
    echo "[!] Sepolicy already cloned"
else
    echo "[*] Cloning the sepolicy tree"
    git clone ${sepolicy_tree_clone}
fi

# Clone the vendor tree
if [ -d "${vendor_tree_path}" ]; then
    echo "[!] Vendor tree already cloned"
else
    echo "[*] Cloning the vendor tree"
    git clone ${vendor_tree_clone}
fi

# Clone the ims vendor tree
if [ -d "${ims_vendor_tree_path}" ]; then
    echo "[!] IMS Vendor tree already cloned"
else
    echo "[*] Cloning the IMS vendor tree"
    git clone ${ims_vendor_tree_clone}
fi

# Clone the firmware vendor tree
if [ -d "${fw_vendor_tree_path}" ]; then
    echo "[!] Firmware Vendor tree already cloned"
else
    echo "[*] Cloning the Firmware vendor tree"
    git clone ${fw_vendor_tree_clone}
fi

# Clone the kernel
if [ -d "${kernel_tree_path}" ]; then
    echo "[!] Kernel already cloned"
else
    echo "[*] Cloning the kernel"
    git clone ${kernel_tree_clone}
fi

# Clone and update the extra repos
if [ -n "${extra_repos_clone}" ]; then
   IFS='|' read -r -a extra_repos_clone <<< "${extra_repos_clone}"
   IFS='|' read -r -a extra_repos_path <<< "${extra_repos_path}"
   IFS='|' read -r -a extra_repos_branch <<< "${extra_repos_branch}"
   for index in "${!extra_repos_clone[@]}"
   do
       echo "[*] Updating extra repo ${extra_repos_path[index]}"
       repo_path="${main_dir}/${extra_repos_path[index]}"
       if [ ! -d "$repo_path" ]; then
            # Clone the repo if it does not exist
            echo "[*] Cloning extra repo ${extra_repos_path[index]}"
            git clone -b "${extra_repos_branch[index]}" "${extra_repos_clone[index]}" "$repo_path"
       fi
       pushd . # Save current directory
       cd "$repo_path"
       git fetch origin "${extra_repos_branch[index]}" && git pull origin "${extra_repos_branch[index]}" || echo "[!] Failed to update ${extra_repos_path[index]}"
       popd # Return to the saved directory
   done
else
    echo "[!] No extra repos to clone"
fi

# Apply patches
if [ -f ../patches.sh ]; then
    echo "[*] Applying patches"
    cp ../patches.sh .
    chmod +x patches.sh
    ./patches.sh
    rm patches.sh
else
    echo "[!] No patches to apply"
fi

# Update the device repos
if [ "${should_update_trees}" = "1" ]; then
    echo "[*] Updating device repos"
    cd ${device_tree_path}
    git fetch origin ${device_tree_branch} && git pull origin ${device_tree_branch} || echo "[!] Failed to update device repos"
    cd ${main_dir}
fi

# Update the sepolicy repos
if [ "${should_update_trees}" = "1" ]; then
    echo "[*] Updating sepolicy repos"
    cd ${sepolicy_tree_path}
    git fetch origin ${sepolicy_tree_branch} && git pull origin ${sepolicy_tree_branch} || echo "[!] Failed to update sepolicy repos"
    cd ${main_dir}
fi

# Update the vendor repos
if [ "${should_update_trees}" = "1" ]; then
    echo "[*] Updating vendor repos"
    cd ${vendor_tree_path}
    git fetch origin ${vendor_tree_branch} && git pull origin ${vendor_tree_branch} || echo "[!] Failed to update vendor repos"
    cd ${main_dir}
fi

# Update the ims vendor repos
if [ "${should_update_trees}" = "1" ]; then
    echo "[*] Updating IMS vendor repos"
    cd ${ims_vendor_tree_path}
    git fetch origin ${ims_vendor_tree_branch} && git pull origin ${ims_vendor_tree_branch} || echo "[!] Failed to update IMS vendor repos"
    cd ${main_dir}
fi

# Update the firmware vendor repos
if [ "${should_update_trees}" = "1" ]; then
    echo "[*] Updating Firmware vendor repos"
    cd ${fw_vendor_tree_path}
    git fetch origin ${fw_vendor_tree_branch} && git pull origin ${fw_vendor_tree_branch} || echo "[!] Failed to update Firmware vendor repos"
    cd ${main_dir}
fi

# Update the kernel repos
if [ "${should_update_kernel}" = "1" ]; then
    echo "[*] Updating kernel repos"
    cd ${kernel_tree_path}
    git fetch origin ${kernel_tree_branch} && git pull origin ${kernel_tree_branch} || echo "[!] Failed to update kernel repos"
    cd ${main_dir}
fi

# Clean the out directory if needed
if [ "${clean_out}" = "1" ]; then
    echo "[*] Cleaning the out directory"
    cd ${main_dir}
    rm -rf out/
fi

# Do a installclean if needed
if [ "${installclean}" = "1" ]; then
    echo "[*] Running installclean"
    cd ${main_dir}
    make installclean
fi

# Clone and set telegram stuff
if [ ! -f "./Telegram/telegram" ]
then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi
TELEGRAM=./Telegram/telegram

# Function to send telegram messages
send_msg()
{
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Send a message to the Telegram channel
if [ "${TELEGRAM_TOKEN}" != "" ] && [ "${TELEGRAM_CHAT}" != "" ]; then
    repo_branch=$(git rev-parse --abbrev-ref HEAD)
    MSG="Build for ${device_codename} started
- Commit: $(git log --pretty=format:'%h - %s' -n 1)
- By: ${git_name}"
    send_msg "${MSG}"
fi

# Build the ROM
echo "[*] Starting the build" && echo "[*] Building ${device_codename}"
. build/envsetup.sh
lunch ${lunch_target}
${make_cmd} || send_msg "Build failed" && exit 1

# Upload the ROM
if [ "${PD_UPLOAD}" = "true" ]; then
    if [ -f "out/target/product/${device_codename}/*.zip" ]; then
        echo "[*] Uploading the ROM"
        export FILE_ID="$(curl -sT "out/target/product/${device_codename}/*.zip" https://pixeldrain.com/api/file/ | grep -o '"id":"[^"]*' | awk -F ':"' '{print $2}')"
        echo "[*] Download the ROM at: https://pixeldrain.com/u/${FILE_ID}"
    else
        echo "[!] No ROM to upload"
    fi
fi

# Send a final message
echo "[*] Done!"

# Send a message to the Telegram channel
if [ "${TELEGRAM_TOKEN}" != "" ] && [ "${TELEGRAM_CHAT}" != "" ]; then
    repo_branch=$(git rev-parse --abbrev-ref HEAD)
    MSG="Build for ${device_codename} finished
- Download the ROM at: https://pixeldrain.com/u/${FILE_ID}
- By: ${git_name}"
    send_msg "${MSG}"
fi