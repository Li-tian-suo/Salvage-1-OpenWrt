# HK09 (IPQ8072A) OpenWrt 构建仓

给 **HK09 / Salvage-1 同款开发板**（高通 IPQ8072A v2.0，NAND 256 MiB + SPI NOR 8 MiB）
编译 OpenWrt 固件的构建仓。

上游源码用 [ccmx200/openwrt-salvage-1-code](https://github.com/ccmx200/openwrt-salvage-1-code)
的 `25.12-nss-vendor-mhi` 分支（ImmortalWrt 25.12 + NSS vendor 驱动），
构建流程参考 [ccmx200/Salvage-1-OpenWrt](https://github.com/ccmx200/Salvage-1-OpenWrt)。

---

## 怎么编译

### 云编译（推荐）

Fork 本仓，然后在自己的仓库里：

1. 进 **Actions** → 左侧选 **HK09 Builder** → 右侧 **Run workflow** → 选 `main` → **Run**
2. 约 2–3 小时后，在 **Artifacts** 里下载 `HK09_firmware_*`
3. 里面会有 `*-squashfs-factory.ubi`（首次刷机用）和 `*-squashfs-sysupgrade.bin`（升级用）

也可以直接 push 到 `main` 触发（改了 `.md` 不会触发）。

### 本地编译

```sh
git clone -b 25.12-nss-vendor-mhi --depth 1 \
    https://github.com/ccmx200/openwrt-salvage-1-code openwrt
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a

# 把本仓的本地包和覆盖层放进去
mkdir -p package/local
cp -a ../local-packages/* package/local/
cp -a ../files .
cp ../.config .

# 注入设备定义（DTS / image 块 / 02_network / 设备符号）
bash ../diy-part2.sh

make defconfig
make -j$(nproc) download
make -j$(nproc)
```

---

## 仓里的东西

| 路径 | 作用 |
|---|---|
| `.config` | 完整配置，482 个包 |
| `dts/ipq8072-hk09.dts` | 设备树：9 个 LED、WPS 按键、SD 卡、双 PCIe、QCA8081 2.5G PHY |
| `diy-part1.sh` | feeds 更新前：追加 qmodem 源（失败只警告） |
| `diy-part2.sh` | feeds 更新后：注入 DTS、image 设备块、网口登记、设备符号 |
| `files/etc/uci-defaults/99-hk09-wireless` | 固化 CN + 5G HE160 + 2.4G HE40 |
| `files/etc/uci-defaults/98-hk09-perf` | 调高 uhttpd 并发，解决 LuCI 慢 |
| `local-packages/homebox` | homebox（aarch64 静态二进制 + LuCI 页面） |
| `local-packages/hello-hk09` | 验证本地包链路的小工具 |

---

## 这块板子的关键事实（都是实测出来的）

### 硬件

| 项目 | 值 |
|---|---|
| SoC | IPQ8072A **v2.0** |
| Target | `qualcommax/ipq807x`（aarch64_cortex-a53 + musl） |
| board_name | `cuicanmx,salvage-1`，model `Salvage-1` |
| NAND | Micron `1590aa2c`，256 MiB，erasesize 128 KiB |
| SPI NOR | MX25U6435F 8 MiB，分区表只用到 `0x690000` |
| 2.5G PHY | QCA8081，PHY ID `0x004d.d101` |
| 千兆 PHY | QCA8075 |
| U-Boot | 2016.01，`bootcmd=ubi part rootfs; ubi read 0x44000000 kernel; bootm 0x44000000` |

### 网口映射（dp ≠ 丝印，是反的）

```
dp1@3a001000  ->  lan3
dp2@3a001200  ->  lan2
dp3@3a001400  ->  lan1
dp5@3a001800  ->  wan (2.5G QCA8081)
```

交换机：`switch_lan_bmp=0x0e`、`switch_wan_bmp=0x20`、
`switch_mac_mode=0x0b`(QSGMII)、`switch_mac_mode1=0x0c`(SGMII_PLUS)、
`switch_mac_mode2=0xff`。

### FIT 配置名必须是 `config@hk01`

不是 `config@hk09`。U-Boot 实测打印 `Using 'config@hk01' configuration`。
（同家族的 ASUS AX89X、Netgear RAX120v2/WAX630、QNAP 301W 也都是 hk01。）

### Wi-Fi：160MHz 取决于监管域，不是硬件

```
country AU: DFS-ETSI   ->  (5150 - 5250 @ 80)   ← 限死 80MHz
country CN: DFS-FCC    ->  (5150 - 5350 @ 160)  ← 才能 160MHz
```

硬件本身是 4x4 160MHz（`VHT Capabilities ... Supported Channel Width: 160 MHz`）。
配了 `htmode=HE160` 但如果 `country` 没生效（回退到 AU），实际只有 80MHz ——
**LuCI 只显示 UCI 里的值，不会告诉你真实带宽**。

代价：CN 下 160MHz 必须用 52–64 这些 DFS 从属信道，**开机要等约 60 秒 CAC**。
期间 `iw dev` 显示 `Channel: 0`、`ip link` 显示 `NO-CARRIER`，不是故障。

想秒启动就用非 DFS 信道 + HE80（36/40/44/48 在 CN 是非 DFS）。

### 功率上限也是监管域决定的

| 监管域 | 2.4G 2412MHz 上限 |
|---|---|
| US | 30 dBm |
| JP | 23 dBm |
| CN | 20 dBm |

同一个硬件、同一份 BDF，只改 `iw reg set`，上限就变 —— 说明是 regulatory，
不是 `board-2.bin` 里的功率表。uci 里写超过上限的 txpower 不会生效。

### LuCI 慢不是板子性能问题

实测：

```
ping 192.168.1.1      0 ms
TCP :80               1 ms
CPU load              0.04
内存                  244 / 884 MB
静态首页              61 ms
LuCI 页面             67 ms（预热后）
```

板子完全空闲。慢的真正原因是 `uhttpd` 的默认 `max_requests=3` ——
LuCI 首屏要拉 10+ 个 JS/CSS，浏览器并发 6 个，服务器只吃 3 个，其余排队。
单个文件预热后 42ms，10 个文件却要 1783ms，全是排队时间。
`98-hk09-perf` 把它调到 20。

另外 uhttpd **不支持 gzip**（带 `Accept-Encoding: gzip` 请求，
返回的 `Content-Encoding` 是空的），575 KB 静态资源全明文传。

### 已知限制

- **AR 分区里的 MAC 无效**（`eth0 MAC Address from ART is not valid`），
  内核会分配随机 MAC。这是原厂固件就有的问题，不是移植引入。
- **开机 5G 要等 60 秒**（DFS CAC），见上面。
- SPI NOR 分区表**不要扩**。那些看起来空的分区（`0:QSEE_1`、`0:APPM_1` 等）
  是高通引导链的双备份槽位，删了就没法从芯片级故障里恢复。

---

## 刷机

**务必先备份全部 mtd 分区再刷。**

```sh
# 板上执行，备份到 /tmp/backup（需要 U 盘或网络导出）
for i in $(seq 0 19); do
    dd if=/dev/mtd$i of=/tmp/backup/mtd$i.bin 2>/dev/null
done
```

刷 `factory.ubi` 走 U-Boot 的 TFTP：

```
IPQ807x# setenv ipaddr 192.168.1.1
IPQ807x# setenv serverip 192.168.1.200
IPQ807x# tftpboot 0x44000000 libwrt-qualcommax-ipq807x-hk09_hk09-squashfs-factory.ubi
IPQ807x# ubi part rootfs
IPQ807x# ubi remove rootfs
IPQ807x# ubi create rootfs $filesize
IPQ807x# ubi write 0x44000000 rootfs $filesize
IPQ807x# reset
```

（`0:ART` 里的 Wi-Fi 校准数据绝对不能丢，`rootfs` 之外的 mtd 分区也不要去动。）

---

## 许可

本仓的脚本和配置：MIT。
上游 OpenWrt / ImmortalWrt：GPL-2.0。
`homebox` 二进制：按其原项目许可。
