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
#   2. 【加容错】qmodem / openclash 都是第三方 feed，GitHub 偶发
#      TLS 中断（本机实测 GnuTLS recv error -110）。上游写法会让
#      一个可选 feed 失败拖垮整个构建。这里改成：
#        - feeds.conf 里已经有了就不重复追加（幂等）
#        - 克隆失败只警告，不退出
#        - 明确告诉用户没装会缺什么
#
#   3. 【固定版本】openclash 用 commit 锁定而不是 ;master。
#      理由：OpenClash 是活跃项目，master 天天变。锁 commit 才能保证
#      今天能编过的配置，下个月还能编过、行为还一样。
#      这个 commit 是 vernesong/OpenClash 在 2026-11 的 HEAD（v0.48.x），
#      与参考项目 PonWRT-TYFZA1 用的完全一致。
#
set -u   # 注意：故意不用 set -e —— 可选 feed 失败不应该让整个构建失败

# ------------------------------------------------------------------ feeds 清单
# 格式：<名字>|<feeds.conf 行>|<失败时缺什么>
FEEDS=(
	"qmodem|src-git qmodem https://github.com/FUjr/QModem.git;main|LuCI 里少一个 4G/5G 模组管理页面"
	"openclash|src-git openclash https://github.com/vernesong/OpenClash.git^e553e82e01c697aefbe1555261a503f425e00ccd|LuCI 里没有「服务 -> OpenClash」页面"
)

for spec in "${FEEDS[@]}"; do
	name="${spec%%|*}"
	rest="${spec#*|}"
	conf="${rest%%|*}"
	effect="${rest#*|}"

	echo "=========================================================="
	echo "=== diy-part1: $name ==="
	echo "=========================================================="

	if grep -qE "^src-git +${name} " feeds.conf.default 2>/dev/null; then
		echo "  feeds.conf.default 里已有 $name，跳过追加"
		# 已有但地址可能不同（例如之前写的是 ;master），这里不改，
		# 但把实际内容打印出来便于排查
		grep -E "^src-git +${name} " feeds.conf.default | sed 's/^/    现有: /'
	else
		echo "$conf" >> feeds.conf.default
		echo "  已追加: $conf"
	fi

	echo
	echo "--- 更新 $name ---"
	if timeout 300 ./scripts/feeds update "$name"; then
		echo "  feeds update $name 成功"
		ok=1
	else
		rc=$?
		echo "::warning::feeds update $name 失败（rc=$rc），跳过"
		echo "  影响：$effect"
		echo "  失败原因通常是 GitHub 网络问题，Actions 重跑一次常常就好。"
		ok=0
	fi

	echo
	if [ "$ok" = "1" ]; then
		echo "--- 安装 $name 的包 ---"
		if timeout 300 ./scripts/feeds install -a -p "$name"; then
			echo "  feeds install -a -p $name 成功"
		else
			rc=$?
			echo "::warning::feeds install -a -p $name 失败（rc=$rc），跳过"
			echo "  影响：$effect"
		fi
	else
		echo "--- $name 未更新，跳过安装 ---"
		# 清掉可能残留的半个目录，否则后面 feeds install -a 会报错
		rm -rf "feeds/$name"
	fi
	echo
done

echo "=========================================================="
echo "=== diy-part1: 完成 ==="
echo "=========================================================="
echo
echo "--- feeds.conf.default 最终内容 ---"
grep -vE '^[[:space:]]*(#|$)' feeds.conf.default | sed 's/^/  /'
exit 0
