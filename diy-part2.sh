#!/bin/bash
#
# HK09 移植注入脚本（免 fork 源码树）
#
# 作用：在你的构建仓里，把 HK09 的设备定义「临时」塞进 ccmx200 的源码树。
#   - 复制 DTS 到 target/linux/qualcommax/.../dts/qcom/
#   - 往 target/linux/qualcommax/image/ipq807x.mk 追加 Device/hk09_hk09
#   - 改 .config 里的设备选择行
#
# 执行位置：openwrt/ 目录下（和 diy-part2.sh 一样，workflow 里 cwd = openwrt）。
# 约定目录：构建仓根目录下放 hk09/dts/ipq8072-hk09.dts
#
# 用法（二选一）：
#   A. 在 diy-part2.sh 末尾加一行：  source "$GITHUB_WORKSPACE/hk09/build/diy-part2.sh"
#   B. 在 workflow 的 "Load custom configuration" 之后单独加一个 run 步骤跑它
#
set -euo pipefail

BOARD_DEV="hk09_hk09"     # 设备名，不能带 '-'（.config 符号里要保持字面一致）
DTS_NAME="ipq8072-hk09.dts"
SOC="ipq8072"
# FIT 里 config 节点的名字，由 mkimage -c 决定（见 include/image-commands.mk:453）。
# 它只是**给配置节点起名字**，不参与硬件识别，但内核 fitblk 驱动按这个名字找 DTB。
#
# 用 config@hk01 而不是 config@hk09：官方 cuicanmx_salvage-1（就是这块板子的
# 原厂设备定义，model = "Salvage-1"）用的就是 config@hk01。
# 同一家族的 ASUS AX89X、Netgear RAX120v2/WAX630、QNAP 301W 也都是 config@hk01。
# 我最初按"HK09 家族惯例"猜了 config@hk09，没有依据 —— 已改回官方值。
DTS_CONFIG="config@hk01"

# 网口名。必须与 DTS 里 dp 节点的 label 严格一致，否则板子能启动但没网口
# （ucidef 会去配置不存在的接口）。
# 实测映射：dp1->lan3  dp2->lan2  dp3->lan1  dp5->wan(2.5G)
LAN_IFACES="lan1 lan2 lan3"
WAN_IFACES="wan"
LAN_IFACES_Q="\"${LAN_IFACES}\""   # 塞进 sed 时需要带引号
WAN_IFACES_Q="\"${WAN_IFACES}\""

WORKSPACE="${GITHUB_WORKSPACE:-$(cd .. && pwd)}"
# 找「本脚本所在的项目根」。兼容三种布局：
#
#   A. 云编译仓库（当前采用）：
#        <repo>/diy-part2.sh          <- 本脚本直接在仓库根
#        <repo>/dts/ipq8072-hk09.dts
#      此时 WORKSPACE 就是仓库根，SRC=WORKSPACE。
#
#   B. 旧的工作区布局：
#        <ws>/hk09/build/diy-part2.sh
#        <ws>/hk09/dts/ipq8072-hk09.dts
#      此时 SRC=WORKSPACE/hk09。
#
# C. 直接放在 <ws>/hk09/diy-part2.sh
#      此时 SRC=WORKSPACE/hk09 也对。
#
# 实测踩过的坑：只写 SRC=WORKSPACE/hk09 时，云编译仓库（布局 A）
# 会因为找不到 dts/ 而直接 die，整条构建失败。
SRC=""
for cand in \
	"${WORKSPACE}" \
	"${WORKSPACE}/hk09" \
	"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" \
	"$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
do
	[ -n "$cand" ] || continue
	if [ -f "${cand}/dts/${DTS_NAME}" ]; then
		SRC="$cand"
		break
	fi
done

if [ -z "$SRC" ]; then
	printf '\033[1;31m[hk09] ERROR:\033[0m 找不到 dts/%s，已试过这些位置：\n' "$DTS_NAME" >&2
	for cand in "${WORKSPACE}" "${WORKSPACE}/hk09" \
	            "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"; do
		printf '    %s/dts/%s\n' "$cand" "$DTS_NAME" >&2
	done
	exit 1
fi

log() { printf '\033[1;36m[hk09]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[hk09] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

log "项目根 = ${SRC}"
[ -d target/linux/qualcommax ] || die "当前目录不是 openwrt 源码树根（缺 target/linux/qualcommax）"

# ---------------------------------------------------------------- 1. 放 DTS
# 两种目录布局都要兼容：
#   ccmx200 fork (LiBwrt 24.x/25.x) : files/arch/arm64/boot/dts/qcom/
#   ImmortalWrt / 新版 OpenWrt      : dts/
if [ -d target/linux/qualcommax/dts ]; then
	DTS_DIR="target/linux/qualcommax/dts"
else
	DTS_DIR="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"
	mkdir -p "$DTS_DIR"
fi
install -m 644 "${SRC}/dts/${DTS_NAME}" "${DTS_DIR}/${DTS_NAME}"
log "DTS -> ${DTS_DIR}/${DTS_NAME}"

# ------------------------------------------ 1b. 可选：把自带的 BDF 做成正式包
# 若存在 ${SRC}/files/board-<设备名>.ipq8074（从原厂固件提出的 BDF），
# 自动注册成 ipq-wifi 包；否则复用现成的 ipq-wifi-cuicanmx_salvage-1。
WIFI_PKG="ipq-wifi-cuicanmx_salvage-1"
BDF_FILE="${SRC}/files/board-${BOARD_DEV}.ipq8074"
IPQ_WIFI_DIR="package/firmware/ipq-wifi"
WIFI_MK="${IPQ_WIFI_DIR}/Makefile"

if [ -f "$BDF_FILE" ] && [ -f "$WIFI_MK" ]; then
	install -m 644 "$BDF_FILE" "${IPQ_WIFI_DIR}/src/"
	if grep -q "generate-ipq-wifi-package,${BOARD_DEV}," "$WIFI_MK"; then
		log "BDF 包已注册，跳过"
	else
		# 挂到 ALLWIFIPACKAGES 上（比改多行 ALLWIFIBOARDS 列表稳）
		pkg_line=$(grep -n '^ALLWIFIPACKAGES:=' "$WIFI_MK" | sed -n '1p' | cut -d: -f1)
		[ -n "$pkg_line" ] && sed -i "${pkg_line}a ALLWIFIPACKAGES += ipq-wifi-${BOARD_DEV}" "$WIFI_MK"
		# generate 调用必须放在文件末尾的 BuildPackage 循环之前
		gen_line=$(grep -n '^$(foreach PACKAGE,$(ALLWIFIPACKAGES)' "$WIFI_MK" | sed -n '1p' | cut -d: -f1)
		gen_text="\$(eval \$(call generate-ipq-wifi-package,${BOARD_DEV},HK09))"
		[ -n "$gen_line" ] && sed -i "${gen_line}i ${gen_text}" "$WIFI_MK"
	fi
	WIFI_PKG="ipq-wifi-${BOARD_DEV}"
	log "BDF 已注册为 ${WIFI_PKG}（源 ${BDF_FILE##*/}）"
	log "  注意：DTS 里的 qcom,ath11k-calibration-variant 必须与 BDF 内 variant 名一致"
else
	log "未提供 ${BDF_FILE##*/}，复用 ${WIFI_PKG}（DTS 变体名需为 Salvage-1）"
fi

# ------------------------------------------------------- 2. 追加 image 设备块
IMAGE_MK="target/linux/qualcommax/image/ipq807x.mk"
[ -f "$IMAGE_MK" ] || die "找不到 $IMAGE_MK"

if grep -q "Device/${BOARD_DEV}" "$IMAGE_MK"; then
	log "image 设备块已存在，跳过"
else
	cat >> "$IMAGE_MK" <<EOF

# ===== HK09 (由 hk09/build/diy-part2.sh 注入) =====
define Device/${BOARD_DEV}
	\$(call Device/FitImage)
	\$(call Device/UbiFit)
	DEVICE_VENDOR := HK09
	DEVICE_MODEL := HK09
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	DEVICE_DTS_CONFIG := ${DTS_CONFIG}
	SOC := ${SOC}
	DEVICE_PACKAGES := ath11k-firmware-ipq8074 ${WIFI_PKG}
endef
TARGET_DEVICES += ${BOARD_DEV}
EOF
	log "image 设备块已追加到 $IMAGE_MK"
fi

# 校验 DTS 文件名与设备名规则一致：DEVICE_DTS = SOC-<设备名最后一个下划线后的部分>
EXPECT_DTS="${SOC}-${BOARD_DEV##*_}.dts"
[ "$EXPECT_DTS" = "$DTS_NAME" ] || die "DTS 名不匹配：OpenWrt 会去找 ${EXPECT_DTS}，但你给的是 ${DTS_NAME}"

# ------------------------------------------------ 2b. 登记 02_network（关键！）
# qualcommax/ipq807x 的 02_network 是按 compatible 字符串做 case 的，
# 未登记的板子会走到 `*) echo "Unsupported hardware. Network interfaces not initialized"`，
# 结果就是：系统起来了，但没有任何 lan/wan 接口，LuCI 打不开。
NETWORK_SH="target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network"
BOARD_COMPAT="hk09,hk09"

if [ -f "$NETWORK_SH" ]; then
	if grep -q "$BOARD_COMPAT" "$NETWORK_SH"; then
		log "02_network 已有 $BOARD_COMPAT，跳过"
	else
		# 在 ipq807x_setup_interfaces() 的 case 之后插一条独立分支
		line=$(awk '
			/^ipq807x_setup_interfaces\(\)/ { infn = 1; next }
			infn && /case "\$board" in/ { print NR; exit }
		' "$NETWORK_SH")
		[ -n "$line" ] || die "在 $NETWORK_SH 里找不到 ipq807x_setup_interfaces 的 case 语句"
		sed -i "${line}a\\\t${BOARD_COMPAT})\\n\\t\\tucidef_set_interfaces_lan_wan ${LAN_IFACES_Q} ${WAN_IFACES_Q}\\n\\t\\t;;" "$NETWORK_SH"
		log "02_network 已登记 ${BOARD_COMPAT} -> ${LAN_IFACES} / ${WAN_IFACES}"
	fi
else
	log "警告：没找到 $NETWORK_SH（本 fork 布局可能不同），需手动登记设备"
fi

# ------------------------------------------------------------ 3. 改 .config
if [ -f .config ]; then
	# 【符号形式 —— 曾经写错，导致设备永远选不中】
	# .config 里的设备选择是：
	#     CONFIG_TARGET_<target>_<subtarget>_DEVICE_<vendor>_<model>
	# 例如 CONFIG_TARGET_qualcommax_ipq807x_DEVICE_aliyun_ap8220=y
	#
	# **不是** CONFIG_TARGET_DEVICE_<target>_<subtarget>_DEVICE_...
	# 那个带额外 DEVICE_ 的形式是 tmp/.config-target.in 里 menuconfig 层的名字，
	# 写进 .config 不会报错，但 kconfig 会当成未知符号静默丢弃，
	# 结果就是「设备没选中，却编出了别的板子的固件」。
	DEV_SYM="CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${BOARD_DEV}"

	# 删掉其它 qualcommax 设备的选择行，只留我们的
	grep -vE '^CONFIG_TARGET_qualcommax_ipq807x_DEVICE_.*=y$' .config > .config.hk09 || true
	mv .config.hk09 .config

	# 显式设为 =y；若已存在 is not set 行则替换掉
	if grep -q "^${DEV_SYM}=" .config; then
		sed -i "s|^${DEV_SYM}=.*|${DEV_SYM}=y|" .config
	elif grep -q "^# ${DEV_SYM} is not set$" .config; then
		sed -i "s|^# ${DEV_SYM} is not set$|${DEV_SYM}=y|" .config
	else
		echo "${DEV_SYM}=y" >> .config
	fi

	# 校验：必须真的能读到 =y
	grep -qxF "${DEV_SYM}=y" .config \
		|| die ".config 里没能写入 ${DEV_SYM}=y"
	log ".config 设备选择 -> ${DEV_SYM}=y"
else
	log "警告：当前目录没有 .config，跳过设备选择"
fi

# ------------------------------------------------ 4. files/ 覆盖层合并
# 约定：files 目录的结构就是 rootfs 的结构，例如
#   etc/uci-defaults/99-hk09             -> /etc/uci-defaults/99-hk09
#   lib/firmware/xxx.bin                 -> /lib/firmware/xxx.bin
#
# 兼容两种布局（本仓用 B，早期约定是 A）：
#   A. ${SRC}/files/             —— 直接放在 hk09/ 下
#   B. ${SRC}/build/files/       —— 放在 hk09/build/ 下（与 diy-part2.sh 同级）
#
# 例外：顶层的 board-*.ipq8074 是 BDF，归 ipq-wifi 包管（见步骤 1b），
#       不能当普通文件塞进 rootfs，否则 /board-hk09_hk09.ipq8074 会多出来。
FILES_SRC=""
if   [ -d "${SRC}/files" ];       then FILES_SRC="${SRC}/files"
elif [ -d "${SRC}/build/files" ]; then FILES_SRC="${SRC}/build/files"
fi

if [ -n "$FILES_SRC" ]; then
	mkdir -p files
	cp -a "${FILES_SRC}/." files/ 2>/dev/null || true
	rm -f files/board-*.ipq8074
	# uci-defaults 必须可执行，否则开机不会运行（cp -a 通常保留了，
	# 但从 Windows/9p 拷过来时可能丢权限，这里强制补一次）
	[ -d files/etc/uci-defaults ] && chmod 755 files/etc/uci-defaults/* 2>/dev/null || true
	n=$(find files -type f | wc -l)
	if [ "$n" -gt 0 ]; then
		log "覆盖层已合并 ${n} 个文件到 openwrt/files/（来源: ${FILES_SRC}）"
		# 用 sed -n '1,10p' 而不是 head -10：脚本开了 pipefail，
		# find 的输出量大时 head 会提前关闭管道让 find 收到 SIGPIPE，
		# 整条管道返回 141，set -e 直接把脚本干掉。
		find files -type f | sed -n '1,10p' | sed 's/^/    /'
		[ "$n" -gt 10 ] && log "    ...（共 ${n} 个）"
	else
		log "警告：${FILES_SRC} 存在但没有可合并的文件"
	fi
else
	log "没有 files 覆盖层（${SRC}/files 和 ${SRC}/build/files 都不存在），跳过"
fi

# ------------------------------------------------ 5. 关于 u-boot 源码（只说明，不改动）
# 曾经试过从 target/linux/qualcommax/Makefile 的 DEFAULT_PACKAGES 里剔除
# uboot-envtools，想避开下载约 20 MB 的 u-boot 源码。**这个思路是错的**：
#
#   tools/mkimage/Makefile 用的是同一份源码包，哈希一模一样：
#       PKG_SOURCE:=u-boot-2025.10.tar.bz2
#       PKG_HASH:=b4f032848e56cc8f213ad59f9132c084dbbb632bc29176d024e58220e0efdf4a
#   而 mkimage 是 host 工具，ipq807x 生成 FIT 镜像时必须调用它：
#       target/linux/qualcommax/image/ipq807x.mk:39
#           PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new
#
# 所以这份源码**绕不过去**。剔除 uboot-envtools 只是让镜像少一个
# fw_printenv/fw_setenv 工具，对下载毫无帮助，反而丢了实用功能。
# 该剔除已回滚，uboot-envtools 保留。
#
# 注意 tools/mkimage 的 PKG_SOURCE_URL 里**没有** denx.de 的 https 源，
# 只有 cyberbits 和 ftp。所以本地若卡在 cyberbits，走云编译最省事：
# Actions runner 在 Azure 上，到各镜像站的连通性都正常。

log "完成：设备 = ${BOARD_DEV}，DTS = ${DTS_NAME}，FIT config = ${DTS_CONFIG}"
