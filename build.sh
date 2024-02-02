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

# Build the ROM
. build/envsetup.sh
lunch ${lunch_target}
${make_cmd}