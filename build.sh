#!/usr/bin/env bash

source config.env

# Init the repo
repo init -u ${repo} -b ${branch}

# Sync the repo
repo sync ${sync_flags}

# Build the ROM
. build/envsetup.sh
${make}