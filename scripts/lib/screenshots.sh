# shellcheck shell=bash
# Shared by setup.sh and screenshots.sh.

# The iPhone size App Store Connect requires, a 6.3-inch display with a Dynamic Island at 1206
# by 2622 pixels, a 13-inch iPad, which it scales down for the smaller ones, and iPhone Duo,
# which it requires from April 2027 of apps built with the iOS 27.1 SDK.
screenshot_devices=("iPhone 18 Pro" "iPad Pro 13-inch (M5) (16GB)" "iPhone Duo")
