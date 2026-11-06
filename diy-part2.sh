#!/bin/bash
#
# diy-part2.sh —— feeds 安装之后、编译之前执行（cwd = openwrt）
#
# 这里只做一件事：调用 HK09 移植注入脚本。
# 注入脚本负责 DTS、image 设备块、02_network 登记、可选 BDF 包、.config 设备选择。
#
set -e

# ---- 通用可选项（按需取消注释）----

# 改默认管理地址
#sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate

# 改默认主题
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 改主机名
#sed -i 's/OpenWrt/HK09/g' package/base-files/files/bin/config_generate

# ---- HK09 设备注入 ----
# 约定：本仓根目录下有一个 hk09/ 目录，内容就是 hk09-port 这套
if [ ! -f "$GITHUB_WORKSPACE/hk09/build/diy-part2.sh" ]; then
	echo "错误：找不到 \$GITHUB_WORKSPACE/hk09/build/diy-part2.sh" >&2
	echo "请把 hk09-port/ 整个目录以 hk09/ 的名字放进构建仓根目录" >&2
	exit 1
fi

source "$GITHUB_WORKSPACE/hk09/build/diy-part2.sh"
