#!/bin/bash
PID=$(adb shell pidof com.soko24.soko_seller_terminal | tr -d '\r')
echo "PID=$PID"
adb shell debuggerd -b "$PID" > /tmp/trace.txt 2>&1
echo "--- main thread ---"
awk '/^"/{p=0} /"main"/{p=1} p' /tmp/trace.txt | head -60
