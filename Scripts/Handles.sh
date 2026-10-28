#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"
	
#将 nf_conntrack_bridge.ko 从 kmod-nft-bridge 的打包列表中移除，避免与 kmod-nf-conntrack-bridge
#安装同一文件（opkg 检测到冲突拒绝安装，导致 package/install Error 255、编译失败）
#模块本体仍由 kmod-nf-conntrack-bridge（firewall4 强依赖）提供，功能不受影响
#注意：nf_add 行位于源码根的 include/netfilter.mk，与 package/kernel/linux/modules/netfilter.mk 是两个不同文件
#先检测后删除再复核：删除后确认文件内不再引用 CONFIG_NF_CONNTRACK_BRIDGE；
#上游改动导致文件缺失或行不存在时打印 WARNING 提示人工检查，不再静默空转
NCF_FILE="./include/netfilter.mk"
echo " "
if [ -f "$NCF_FILE" ] && grep -q "nf_add.*CONFIG_NF_CONNTRACK_BRIDGE" "$NCF_FILE"; then
	sed -i "/nf_add.*CONFIG_NF_CONNTRACK_BRIDGE/d" "$NCF_FILE"
	if grep -q "CONFIG_NF_CONNTRACK_BRIDGE" "$NCF_FILE"; then
		echo "WARNING: CONFIG_NF_CONNTRACK_BRIDGE still referenced in $NCF_FILE - check manually!"
	else
		echo "nf-conntrack-bridge conflict fixed!"
	fi
elif [ -f "$NCF_FILE" ]; then
	echo "nf-conntrack-bridge conflict line not present - upstream may have fixed it already."
else
	echo "WARNING: $NCF_FILE not found - upstream layout changed, check manually!"
fi
