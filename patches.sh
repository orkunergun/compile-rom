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
git fetch https://github.com/begonia-dev/android_frameworks_av
git cherry-pick 6a074a11bfe85c3fabcd84ff1ab0c270c3a37b61^..a92e88889bffca15c422b5011c20c22f6a25c45a || git cherry-pick --skip
echo "[!] frameworks/av commits after"
git log -n 6 --oneline
cd ../..
cd frameworks/native
echo "[!] frameworks/native commits before"
git log -n 6 --oneline
git fetch https://github.com/begonia-dev/android_frameworks_native
git cherry-pick 16eb76b5b1aa021dc3f00852c50a2f1fcf282088 || git cherry-pick --skip
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