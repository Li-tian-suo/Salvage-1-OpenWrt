# 固件内容实证（解压后验证）

> 不只是"manifest 里有包"，而是**真的把 squashfs 解出来看文件**。
> 这一份是最终确认。

---

## 一、验证方法

```sh
BIN=libwrt-qualcommax-ipq807x-hk09_hk09-squashfs-sysupgrade.bin

# 1. 找 squashfs 魔数
grep -obUaP 'hsqs' "$BIN" | cut -d: -f1
# -> 5699072

# 2. 从该偏移解压
unsquashfs -o 5699072 -d root/ "$BIN"
# -> 解出 2588 个文件
```

脚本：`.check/extract-firmware.sh`

---

## 二、wifiguard 三个文件（这是最关心的）

```
[在] usr/bin/hk09-wifiguard              2579 字节  权限 755
[在] etc/init.d/hk09-wifiguard           1248 字节  权限 755
[在] etc/uci-defaults/97-hk09-wifiguard   618 字节  权限 755
```

**权限全是 755** —— 这一点很关键。

之所以特别验证，是因为踩过一个坑：`.gitignore` 里写 `bin/` 把
`files/usr/bin/hk09-wifiguard` 整个忽略了，提交里只有另外两个文件，
固件里就少了主程序，init 脚本会指向空文件无限 respawn 失败。

现在三个都在，`可执行位` 也没丢。

---

## 三、caldata 修复（Wi-Fi 能起来的关键）

解压后读 `/etc/hotplug.d/firmware/11-ath11k-caldata`：

```
12-	cuicanmx,salvage-1|\
13:	hk09,hk09)
14-		# 与原厂一致：原厂 /lib/read_caldata_to_fs.sh 在 IPQ8074 分支执行
```

第 12-13 行是把 `hk09,hk09)` 用反斜杠续行拼到 `cuicanmx,salvage-1)` 后面，
形成 case 分支：

```sh
	cuicanmx,salvage-1|\
	hk09,hk09)
		...caldata_extract "0:ART" 0x1000 0x20000...
		;;
```

**这就是上次 Wi-Fi 完全起不来的根因修复，已确认在固件里。**

---

## 四、OpenClash

`/usr/lib/lua/luci/view/openclash/` 存在，包含：

```
cfg_check.htm
config_edit.htm
config_editor.htm
config_merge_editor.htm
config_upload.htm
...
```

说明 OpenClash 的 LuCI 页面文件已正确安装，
且 `luci-compat` + `lua` + `luci-lua-runtime` 的兼容层也在
（manifest 已验证）。

---

## 五、为什么在二进制里 grep 不到明文

```sh
grep -oa 'hk09-wifiguard' sysupgrade.bin    -> 0 次
grep -oa 'hk09-perf'      sysupgrade.bin    -> 0 次
```

这是**正常的**：squashfs 是压缩的，文件内容在压缩块里，grep 看不到明文。

所以验证固件内容**必须**解压，不能靠 `strings`/`grep`。
这是我一开始想错的地方。

---

## 六、pstore 的验证方式不同

pstore 是内核配置，不是文件，所以看不到文件。

正确验证途径：

1. **构建日志**（已确认）：
   ```
   [hk09] target/linux/qualcommax/config-6.12: 已开启 pstore/ramoops + panic_on_oops + panic_timeout=30
   [hk09]       CONFIG_PSTORE=y
   [hk09]       CONFIG_PSTORE_RAM=y
   [hk09]       CONFIG_PSTORE_CONSOLE=y
   [hk09]       CONFIG_PSTORE_PMSG=y
   [hk09]       CONFIG_PSTORE_COMPRESS=y
   [hk09]       CONFIG_PANIC_TIMEOUT=30
   [hk09]       CONFIG_PANIC_ON_OOPS=y
   ```

2. **initramfs 二进制里能搜到 `pstore`/`ramoops` 字样**：
   ```
   [找到] initramfs 里有 pstore/ramoops 字样
   ```

3. **刷机后在板子上看**：
   ```sh
   zcat /proc/config.gz | grep PSTORE
   ls /sys/fs/pstore/
   ```

---

## 七、完整验证清单（36 项已过）

### manifest 层面（492 个包）

| 类别 | 包 |
|---|---|
| Wi-Fi | `ath11k-firmware-ipq8074`, `kmod-ath11k-ahb` |
| 主题 | `luci-theme-argon` 2.4.7, `luci-app-argon-config`, `luci-i18n-argon-config-zh-cn`, `luci-theme-bootstrap` |
| OpenClash | `luci-app-openclash` 0.48.002, `ruby` 3.4.9, `ruby-yaml`, `kmod-nft-tproxy`, `ipset` 7.24, `luci-compat`, `lua` 5.1.5, `luci-lua-runtime`, `unzip` |
| USB/FS | `kmod-usb-net-sierrawireless`, `ntfs-3g`, `exfat-mkfs`, `exfat-fsck`, `f2fsck`, `mkf2fs`, `fuse3-utils`, `libudev-zero`, `kmod-fs-ntfs3`, `ksmbd-server` |
| 自定义 | `homebox` 0.2.0, `hello-hk09` |
| NSS | `kmod-qca-nss-drv`, `kmod-qca-nss-ecm`, `kmod-qca-nss-dp` |
| 基础 | `dnsmasq-full`（且无多余的基础 dnsmasq）, `uhttpd`, `firewall4`, `dropbear` |

`sha256sums` 全部匹配。

### 文件层面（解压后）

- wifiguard 三件套（含可执行位）
- caldata 脚本含 `hk09,hk09` 分支
- OpenClash 的 LuCI 视图文件
- 共 2588 个文件

---

## 八、还没验证的（只能上板）

以下三项必须在真板子上跑：

1. **Wi-Fi 是否真的起来**
   ```sh
   iw dev | grep -E 'Interface|channel'
   ls /lib/firmware/ath11k/IPQ8074/hw2.0/
   ```

2. **OpenClash 页面能否打开**
   LuCI -> 服务 -> OpenClash

3. **pstore 是否生效**
   ```sh
   zcat /proc/config.gz | grep PSTORE
   ```

以及最关键的：**跑一次 homebox 看 Wi-Fi 会不会再挂、pstore 能不能抓到现场。**
