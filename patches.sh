#!/usr/bin/env bash

# Skip the cherry pick if the patch is already applied
cd frameworks/av
git cherry-pick --abort
cd ../..
cd frameworks/native
git cherry-pick --abort
cd ../..
cd packages/modules/Wifi
git cherry-pick --abort
cd ../../..

# Apply patches
cd frameworks/av
echo "[!] frameworks/av commits before"
git log -n 6 --oneline
git fetch https://github.com/xiaomi-begonia-dev/frameworks_av
git cherry-pick 4c05700781409a0ba321adb8dc67e14ce918e52b^..72b8d3e9182b172ad0f161616c391b0b7ac59989 || git cherry-pick --skip
echo "[!] frameworks/av commits after"
git log -n 6 --oneline
cd ../..
cd frameworks/native
echo "[!] frameworks/native commits before"
git log -n 6 --oneline
git fetch https://github.com/xiaomi-begonia-dev/frameworks_native
git cherry-pick d964eeba4146ab0045858a05604f5202b2e874d8 || git cherry-pick --skip
echo "[!] frameworks/native commits after"
git log -n 6 --oneline
cd ../..
cd packages/modules/Wifi
echo "[!] packages/modules/Wifi commits before"
git log -n 6 --oneline
git fetch https://github.com/xiaomi-begonia-dev/packages_modules_Wifi
git cherry-pick fa93e2da9aba4a79e7df4d4db859cb2ef1d5a8ff || git cherry-pick --skip
echo "[!] packages/modules/Wifi commits after"
git log -n 6 --oneline
cd ../../..