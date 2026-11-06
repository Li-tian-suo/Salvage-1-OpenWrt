#
# 示例：一个纯 shell 的自定义本地包
#
# 放法：local-packages/<目录名>/，每个目录一个包。
# 构建时会被拷到 openwrt/package/local/<目录名>/，然后和普通包一样参与编译。
#
# 这个包没有源码（PKGARCH:=all），只装一个脚本，用来验证本地包链路通不通。
#
include $(TOPDIR)/rules.mk

PKG_NAME:=hello-hk09
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=HK09 Port
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/hello-hk09
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=HK09 bring-up helper
  PKGARCH:=all
endef

define Package/hello-hk09/description
  Small helper that prints board identity and a few bring-up facts.
  Used to verify that local-packages/ actually makes it into the image.
endef

define Build/Compile
endef

define Package/hello-hk09/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/hello-hk09.sh $(1)/usr/bin/hello-hk09
endef

$(eval $(call BuildPackage,hello-hk09))
