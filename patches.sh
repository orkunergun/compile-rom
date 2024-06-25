cd vendor/derp/signing/keys
wget -O keys.tar https://drive.orkunergun.eu.org/api/raw/?path=/DerpFest-AOSP/Keys/keys.tar
tar xvf keys.tar
rm -rf keys.tar
cd -
rm -rf device/xiaomi/lancelot/vendorsetup.sh