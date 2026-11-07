# Run #8 编译结果（2026-11-07）

> 提交 `4c3a1de`，全部 21 个步骤 success，编译耗时 93 分 23 秒。
> 产物 117.8 MB，已下载到 `firmware/run8/out/`。

---

## 一、结果总览

| 项目 | 值 |
|---|---|
| Run | **#8**（id `42269817754`） |
| 提交 | `4c3a1de` （workflow concurrency 修正） |
| 开始 | 2026-11-06 18:20:36 UTC |
| 结束 | 2026-11-06 19:53:59 UTC |
| 耗时 | **1 小时 33 分 23 秒** |
| 结论 | **success**（21/21 步骤全过） |
| 产物 | 117.8 MB（artifact id `13535634119`） |

同批的 **Run #7 也 success**（提交 `7871859`），两者软件包内容相同。

### 为什么这次比 Run #4 慢一倍

Run #4 编译 3733 秒（62 分钟），这次 5603 秒（93 分钟）。

原因：新增了 **ruby 3.4.9**（编译极慢）+ **OpenClash** + 大量 USB/文件系统
kmod。包数从 482 涨到 492，但 ruby 一个就占了很大比重。

---

## 二、21 个步骤全部成功

```
Set up job                            success
Checkout                              success
显示将要编译的配置                      success
安装编译依赖                           success
克隆源码                               success
注入 feeds（diy-part1.sh）             success
更新并安装 feeds                        success
修补 pcie_mhi（关闭 NSS offload hook）  success
放入本地包                              success
载入配置并注入设备（diy-part2.sh）       success   ← 关键
校验设备符号真的生效                     success   ← 关键
缓存下载目录                            success
make defconfig 并下载依赖              success
核对包是否真的被选中                     success   ← 关键
编译                                   success
核对 homebox 进了固件                   success
检查磁盘                               success
整理产物                               success
上传固件 artifact                       success
Post 缓存下载目录                       success
Post Checkout                          success
```

---

## 三、关键修复确认生效（来自构建日志原文）

### 1. caldata 补丁 —— Wi-Fi 能起来的关键

```
[hk09] 已给 caldata 脚本加上 hk09,hk09 分支
   13-	hk09,hk09)
[hk09] 02_network 已登记 hk09,hk09 -> lan1 lan2 lan3 / wan
```

### 2. pstore / ramoops —— 崩溃现场

```
[hk09] target/linux/qualcommax/config-6.12: 已开启 pstore/ramoops + panic_on_oops + panic_timeout=30
[hk09] target/linux/qualcommax/ipq807x/config-default: 已开启 pstore/ramoops + panic_on_oops + panic_timeout=30
[hk09] --- target/linux/qualcommax/config-6.12 中的 pstore/panic 行 ---
      CONFIG_PSTORE=y
      CONFIG_PSTORE_RAM=y
      CONFIG_PSTORE_CONSOLE=y
      CONFIG_PSTORE_PMSG=y
      CONFIG_PSTORE_COMPRESS=y
      CONFIG_PANIC_TIMEOUT=30
      CONFIG_PANIC_ON_OOPS=y
```

### 3. 设备符号

```
期望设备: hk09_hk09
OK: CONFIG_TARGET_qualcommax_ipq807x_DEVICE_hk09_hk09=y
```

### 4. 包丢弃数

```
=== 声明了但被 kconfig 丢弃的包 ===
共丢弃 0 个（少量属正常：版本差异导致包名变化）

=== 关键包必须存在 ===
OK   homebox
OK   kmod-qca-nss-drv
OK   kmod-qca-nss-ecm
```

**0 个包被丢弃** —— 配置里写的全生效了。

### 5. homebox

```
>>> homebox
homebox                  homebox 0.2.0
IN-IMAGE homebox
```

---

## 四、产物清单

| 文件 | 大小 | 对比 Run #4 |
|---|---|---|
| `libwrt-qualcommax-ipq807x-hk09_hk09-initramfs-uImage.itb` | 46,380,144 | +11.5 MB |
| `libwrt-qualcommax-ipq807x-hk09_hk09-squashfs-factory.ubi` | 40,239,104 | +10.2 MB |
| `libwrt-qualcommax-ipq807x-hk09_hk09-squashfs-sysupgrade.bin` | 38,605,059 | +9.9 MB |
| `libwrt-qualcommax-ipq807x-hk09_hk09.manifest` | 15,430 | +1,098 |
| `profiles.json` | 2,759 | — |
| `sha256sums` | 812 | — |
| `config.buildinfo` | 7,641 | — |
| `feeds.buildinfo` | 893 | — |
| `version.buildinfo` | 11 | — |

**sha256 全部校验通过。**

---

## 五、manifest 校验：36 项全过

manifest 共 **492 个包**，逐项核对关键包：

### Wi-Fi
```
ath11k-firmware-ipq8074    2026.08.21~0c817c46-r1
kmod-ath11k-ahb            6.12.108.6.18.39-r1
```

### 主题（Argon）
```
luci-theme-argon                     2.4.7-r20260824
luci-theme-bootstrap                 26.309.25225~c38e566
luci-app-argon-config                26.309.25225~c38e566
luci-i18n-argon-config-zh-cn         26.309.25225~c38e566
```

### OpenClash 全套
```
luci-app-openclash     0.48.002
ruby                   3.4.9-r1
ruby-yaml              3.4.9-r1
kmod-nft-tproxy        6.12.108-r1
ipset                  7.24-r1
luci-compat            26.309.25225~c38e566
lua                    5.1.5-r11
luci-lua-runtime       26.309.25225~c38e566
unzip                  6.0-r9
```

### USB / 文件系统
```
kmod-usb-net-sierrawireless   6.12.108-r1
ntfs-3g                       2022.10.3-r1
exfat-mkfs / exfat-fsck       1.2.9-r1
f2fsck / mkf2fs               1.16.0-r4
fuse3-utils                   3.17.3-r1
libudev-zero                  1.0.4-r1
kmod-fs-ntfs3                 6.12.108-r1
ksmbd-server                  3.5.6-r1
```

### 自定义 / NSS
```
homebox              0.2.0-r1
hello-hk09           1.0-r1
kmod-qca-nss-drv     6.12.108.11.4.0.5.2021.09.13~53e5863-r17
kmod-qca-nss-ecm     6.12.108.12.5.2024.11.06~30fbfa4-r7
kmod-qca-nss-dp      6.12.108.2025.11.24~19c51af0-r1
```

### 基础
```
dnsmasq-full    2.93-r1        （确认没有多余的基础 dnsmasq）
uhttpd          2026.06.16~7b1bec45-r1
firewall4       2025.03.17~b6e51575-r2
dropbear        2025.89-r3
```

---

## 六、刷机前必读

### 空间不够！必须先腾出 UBI 卷

板子当前 `rootfs` 只有 **182 LEB = 23,109,632 B ≈ 22 MiB**，
而新的 `factory.ubi` 是 **40,239,104 B**，需要约 **317 LEB**。
`available LEBs = 0`。

**必须**在 U-Boot 里先删再建：

```
ubi remove rootfs
ubi remove rootfs_data
ubi create rootfs $filesize
ubi write 0x44000000 rootfs $filesize
```

**绝不能碰** `mtd18`（`0:ART`）和 `mtd15`（`0:APPSBLENV`）。

### 最安全的第一步：initramfs，不写 flash

```
tftpboot 0x44000000 libwrt-qualcommax-ipq807x-hk09_hk09-initramfs-uImage.itb
bootm 0x44000000
```

initramfs 是 46 MB，跑在内存里，**完全不碰 flash**。
确认 Wi-Fi 起来了、OpenClash 页面能开，再决定要不要刷。

### U-Boot 备忘

```
bootcmd=ubi part rootfs; ubi read 0x44000000 kernel; bootm 0x44000000
```

- **没有 `boot` 命令**，用 `run bootcmd`
- FIT 配置名 **`config@hk01`**
- 串口 115200 8N1，**绝不发 Ctrl-C**（会掉登录 shell）
- U-Boot 会吞字符，命令要逐字符发（间隔 8 ms）

---

## 七、刷完之后验证什么

### 1. Wi-Fi（这是上次挂的地方）

```sh
iw dev | grep -E 'Interface|channel'
# 期望看到两个接口：
#   phy0-ap0  ch36 (5180 MHz)  80 MHz
#   phy1-ap0  ch1  (2412 MHz)  20 MHz

ls /lib/firmware/ath11k/IPQ8074/hw2.0/
# 期望有 cal-ahb-c000000.wifi.bin（上次就是缺这个）
```

### 2. OpenClash

LuCI → 服务 → OpenClash，页面能打开即说明 lua 兼容层正常。

### 3. 主题

LuCI → 系统 → 系统 → 语言和界面 → 设计，应能看到 Argon。

### 4. 看门狗

```sh
ps | grep wifiguard
logread | grep hk09-wifiguard
```

### 5. pstore（下次崩溃时的关键）

```sh
ls /sys/fs/pstore/
# 现在应该是空的；崩溃后会有 dmesg-ramoops-0
```

### 6. 复现「跑 homebox 就 Wi-Fi 去世」

跑一次 homebox 测速，然后再查：

```sh
iw dev                      # 接口还在不在
cat /sys/fs/pstore/*        # 有崩溃现场就是抓到了
dmesg | grep -iE 'nss|ath11k' | tail -40
logread | grep hk09-wifiguard
```

**这次的 pstore 是打开的，如果 NSS 真的崩了，能看到调用栈。**

---

## 八、本地文件位置

```
firmware/run8/
  art.zip                                  123,511,834  （原始 artifact）
  out/
    libwrt-...-initramfs-uImage.itb         46,380,144
    libwrt-...-squashfs-factory.ubi         40,239,104
    libwrt-...-squashfs-sysupgrade.bin      38,605,059
    libwrt-...manifest                          15,430
    profiles.json                                2,759
    sha256sums                                     812
    config.buildinfo                             7,641
    feeds.buildinfo                                893
    version.buildinfo                               11
```
