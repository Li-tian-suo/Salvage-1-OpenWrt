#
# homebox —— 内网测速工具（含 LuCI 启停页面）
#
# 来源：PonWRT-TYFZA1/port/packages/homebox
#
# 二进制随仓库提供，构建时不联网：
#   files/homebox   aarch64 / 静态链接（无 PT_INTERP、无 NEEDED）
#                   MD5 fc84eb75e76868c2d873d55e733d12b1
#                   版本 0.2.0，上游 https://github.com/XGHeaven/homebox
#
# 因为是静态链接，运行时不需要额外的 .so，直接放到 ipq807x
# （aarch64_cortex-a53 + musl）上就能跑。
#
# 不设 PKGARCH：包会自动继承目标架构（aarch64_cortex-a53）。
# 硬写 PKGARCH 反而有风险 —— 值对不上时包不会出现在菜单里，且报错很隐晦。
#
# LuCI 页面位于「服务 → Homebox」，可改监听地址/端口/worker 数/
# 最大连接数/keep-alive，并支持启停与运行状态显示。
# 测速时用浏览器访问 http://<路由器IP>:3300
#
include $(TOPDIR)/rules.mk

PKG_NAME:=homebox
PKG_VERSION:=0.2.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=HK09 Port

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/homebox
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Homebox - 内网测速工具（含 LuCI 启停页面）
  URL:=https://github.com/XGHeaven/homebox
  DEPENDS:=+libc
endef

define Package/homebox/description
 Homebox 家庭网络测速工具箱，浏览器端即可压测内网链路，
 最高可测 10G。本包附带 LuCI 启停与端口配置页面。

 二进制为 aarch64 静态链接，随包提供，构建时无需联网。
endef

define Package/homebox/conffiles
/etc/config/homebox
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/homebox/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/homebox $(1)/usr/bin/homebox

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/homebox.config $(1)/etc/config/homebox

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/homebox.init $(1)/etc/init.d/homebox

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/homebox
	$(INSTALL_DATA) ./files/luci/index.js $(1)/www/luci-static/resources/view/homebox/index.js

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/luci/menu.json $(1)/usr/share/luci/menu.d/luci-app-homebox.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci/acl.json $(1)/usr/share/rpcd/acl.d/luci-app-homebox.json
endef

$(eval $(call BuildPackage,homebox))
