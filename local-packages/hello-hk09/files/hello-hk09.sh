#!/bin/sh
# HK09 板级自检小工具（示例本地包 hello-hk09 的载荷）
# 只读，不修改任何东西。

echo "=== HK09 bring-up ==="
echo "model      : $(cat /proc/device-tree/model 2>/dev/null)"
echo "compatible : $(tr '\0' ' ' < /proc/device-tree/compatible 2>/dev/null)"
echo "kernel     : $(uname -r)"
echo "uptime     : $(cat /proc/uptime 2>/dev/null | cut -d' ' -f1) s"
echo
echo "--- 网口 ---"
for i in /sys/class/net/*; do
	n=$(basename "$i")
	[ "$n" = "lo" ] && continue
	echo "$n: $(cat $i/address 2>/dev/null) carrier=$(cat $i/carrier 2>/dev/null)"
done
echo
echo "--- mtd ---"
cat /proc/mtd 2>/dev/null | head -20
echo
echo "--- Wi-Fi ---"
ls /sys/class/ieee80211 2>/dev/null || echo "(无)"
dmesg 2>/dev/null | grep -i ath11k | tail -5
