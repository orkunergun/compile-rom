#!/usr/bin/env bash

source config.env

# Create the build directory

if [ -f rom/.repo/manifest.xml ]; then
    echo "Repo already initialized"
    cd rom
    exit 1
else
    mkdir -p rom
    cd rom
fi

# Init the repo
repo init -u ${repo} -b ${repo_branch}

# Sync the repo
repo sync ${sync_flags}

# Build the ROM
. build/envsetup.sh
${make}