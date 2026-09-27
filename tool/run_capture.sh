#!/bin/bash
# Run the app on-device and capture all Dart/Flutter stdout for startup diagnosis.
cd /var/www/soko/app/soko_seller_terminal || exit 1
adb logcat -c 2>/dev/null
timeout 900 flutter run -d 192.168.1.66:5555 --debug 2>&1
