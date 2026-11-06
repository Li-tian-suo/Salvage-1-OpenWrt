#!/bin/bash
#
# diy-part1.sh —— feeds 更新之前执行（cwd = openwrt 源码树根目录）
#
# 与上游 ccmx200 版本的区别：
#
#   1. 【修 bug】上游那行「更新并安装软件源包」是裸中文，没有 '#'。
#      Actions 用 `bash -e` 执行这个脚本，裸中文会被当成命令，
#      得到 `更新并安装软件源包: command not found`，退出码 127，
#      整个 "Load custom feeds" 步骤直接失败。这里补上注释符。
#
#   2. 【加容错】qmodem 是第三方 feed（FUjr/QModem），GitHub 偶发
#      TLS 中断（本机实测 GnuTLS recv error -110）。上游写法会让
#      一个可选 feed 失败拖垮整个构建。这里改成：
#        - feeds.conf 里已经有了就不重复追加（幂等）
#        - 克隆失败只警告，不退出
#        - 明确告诉用户没装 qmodem 会缺什么
#
# qmodem 的用途：4G/5G 模组管理（QModem 是 LuCI 上的模组管理界面）。
# 本板是路由器形态，不强依赖它；没有它也能正常编译出固件。
#
set -u   # 注意：故意不用 set -e —— 可选 feed 失败不应该让整个构建失败

QMODEM_CONF='src-git qmodem https://github.com/FUjr/QModem.git;main'

echo "=== diy-part1: 追加 qmodem feed ==="
if grep -q 'qmodem' feeds.conf.default 2>/dev/null; then
	echo "  feeds.conf.default 里已有 qmodem，跳过追加"
else
	echo "$QMODEM_CONF" >> feeds.conf.default
	echo "  已追加: $QMODEM_CONF"
fi

echo
echo "=== diy-part1: 更新 qmodem feed ==="
# 给 feed 更新加超时和重试，避免网络抖动卡死整个 job
if timeout 300 ./scripts/feeds update qmodem; then
	echo "  feeds update qmodem 成功"
	QMODEM_OK=1
else
	rc=$?
	echo "::warning::feeds update qmodem 失败（rc=$rc），跳过 qmodem"
	echo "  这不影响固件编译，只是 LuCI 里少一个 4G/5G 模组管理页面。"
	echo "  失败原因通常是 GitHub 网络问题，Actions 重跑一次常常就好。"
	QMODEM_OK=0
fi

echo
if [ "$QMODEM_OK" = "1" ]; then
	echo "=== diy-part1: 安装 qmodem 包 ==="
	if timeout 300 ./scripts/feeds install -a -p qmodem; then
		echo "  feeds install -a -p qmodem 成功"
	else
		rc=$?
		echo "::warning::feeds install -a -p qmodem 失败（rc=$rc），跳过"
	fi
else
	echo "=== diy-part1: qmodem 未更新，跳过安装 ==="
	# 清掉可能残留的半个目录，否则后面 feeds install -a 会报错
	rm -rf feeds/qmodem
fi

echo
echo "=== diy-part1: 完成 ==="
exit 0
