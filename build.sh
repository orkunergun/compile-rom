#!/usr/bin/env bash

source config.env

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
    fi
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
else
    echo "Repo not initialized, exiting..."
    exit 1
fi

# Apply patches
if [ -f patches.sh ]; then
    bash patches.sh
fi

# Build the ROM
. build/envsetup.sh
${make}