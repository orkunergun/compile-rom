#!/usr/bin/env bash

source config.env

# Set git config
git config --global user.email "${git_email}"
git config --global user.name "${git_name}"

# Create the build directory
if [ -f rom/.repo/manifest.xml ]; then
    echo "Repo already initialized"
    cd rom
else
    mkdir -p rom
    cd rom
    # Init the repo
    repo init -u ${repo} -b ${repo_branch} --depth=10
fi

# Sync the repo
if [ -d .repo ]; then
    if [ "${should_skip_sync}" = "1" ]; then
        echo "Skipping sync"
    else
        repo sync ${sync_args}
    fi
else
    echo "Repo not initialized, exiting..."
    exit 1
fi

# Clone the device tree
if [ -d "${device_tree_path}" ]; then
    echo "Device tree already cloned"
else
    git clone ${device_tree_clone}
fi

# Clone the sepolicy tree
if [ -d "${sepolicy_tree_path}" ]; then
    echo "Sepolicy already cloned"
else
    git clone ${sepolicy_tree_clone}
fi

# Clone the vendor tree
if [ -d "${vendor_tree_path}" ]; then
    echo "Vendor tree already cloned"
else
    git clone ${vendor_tree_clone}
fi

# Clone the ims vendor tree
if [ -d "${ims_vendor_tree_path}" ]; then
    echo "IMS Vendor tree already cloned"
else
    git clone ${ims_vendor_tree_clone}
fi

# Clone the firmware vendor tree
if [ -d "${fw_vendor_tree_path}" ]; then
    echo "Firmware Vendor tree already cloned"
else
    git clone ${fw_vendor_tree_clone}
fi

# Clone the kernel
if [ -d "${kernel_tree_path}" ]; then
    echo "Kernel already cloned"
else
    git clone ${kernel_tree_clone}
fi

# Clone extra repos
if [ -n "${extra_repos_clone}" ]; then
    IFS='|' read -r -a extra_repos <<< "${extra_repos_clone}"
    IFS='|' read -r -a extra_repos_path <<< "${extra_repos_path}"
    for index in "${!extra_repos[@]}"
    do
        if [ -d "${extra_repos_path[index]}" ]; then
            echo "Extra repo ${extra_repos[index]} already cloned"
        else
            git clone ${extra_repos[index]} ${extra_repos_path[index]}
        fi
    done
fi

# Apply patches
if [ -f ../patches.sh ]; then
    echo "Applying patches"
    cp ../patches.sh .
    chmod +x patches.sh
    ./patches.sh
    rm patches.sh
else
    echo "No patches to apply"
fi

# Clean the out directory if needed
if [ "${clean_out}" = "1" ]; then
    rm -rf out/
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
. build/envsetup.sh
lunch ${lunch_target}
${make_cmd} || send_msg "Build failed" && exit 1

# Upload the ROM
if [ "${PD_UPLOAD}" = "true" ]; then
    if [ -f "out/target/product/${device_codename}/*.zip" ]; then
        echo "Uploading the ROM"
        export FILE_ID="$(curl -sT "out/target/product/${device_codename}/*.zip" https://pixeldrain.com/api/file/ | grep -o '"id":"[^"]*' | awk -F ':"' '{print $2}')"
        echo "Download the ROM at: https://pixeldrain.com/u/${FILE_ID}"
    else
        echo "No ROM to upload"
    fi
fi

# Send a final message
echo "Done"

# Send a message to the Telegram channel
if [ "${TELEGRAM_TOKEN}" != "" ] && [ "${TELEGRAM_CHAT}" != "" ]; then
    repo_branch=$(git rev-parse --abbrev-ref HEAD)
    MSG="Build for ${device_codename} finished
- Download the ROM at: https://pixeldrain.com/u/${FILE_ID}
- By: ${git_name}"
    send_msg "${MSG}"
fi