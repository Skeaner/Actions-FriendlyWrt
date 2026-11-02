#!/bin/bash

sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' configs/rockchip/01-nanopi

# Passwall, Golang and extra software customization
if [ -d "friendlywrt" ]; then
    pushd friendlywrt

    # Update feeds first to populate standard packages
    ./scripts/feeds update -a

    # 1. Update Go language package to 1.27.x
#    rm -rf feeds/packages/lang/golang
#    git clone --depth 1 --branch 27.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

    # 2. Remove conflicting / duplicate packages in feeds
    rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
    rm -rf feeds/luci/applications/luci-app-passwall

    # 3. Clone passwall-packages and passwall-luci directly to package/
    rm -rf package/passwall-packages
    git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
    # Remove Go-based packages to avoid compilation failure with old Golang
    rm -rf package/passwall-packages/{xray-core,sing-box,v2ray-geodata,v2ray-core,geoview}

    rm -rf package/passwall-luci
    git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci

    # 4. Clone Lucky package
    rm -rf package/lucky
    git clone --depth 1 https://github.com/gdy666/luci-app-lucky package/lucky

    # 5. Install feeds
    ./scripts/feeds install -a

    # 6. Download Prebuilt Binaries (Solution for Golang version conflict)
    # This avoids compiling xray/sing-box with old Golang and breaking Docker
    mkdir -p files/usr/bin

    # Download Xray
    XRAY_VERSION='v26.10.31'
    curl -L https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-arm64-v8a.zip -o xray.zip
    unzip -o xray.zip xray -d files/usr/bin/
    chmod +x files/usr/bin/xray
    rm -f xray.zip

    # Download Sing-Box
    SB_VERSION='1.14.4'
    curl -L https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}/sing-box-${SB_VERSION}-linux-arm64.tar.gz -o sing-box.tar.gz
    tar -zxvf sing-box.tar.gz --strip-components=1 -C files/usr/bin/ sing-box-${SB_VERSION}-linux-arm64/sing-box
    chmod +x files/usr/bin/sing-box
    rm -f sing-box.tar.gz

    popd
fi

# Enable Passwall & extra packages in configs/rockchip/*
for cfg in configs/rockchip/01-nanopi configs/rockchip/*; do
    if [ -f "$cfg" ]; then
        # Remove existing xray/sing-box package selections if any
        sed -i -e '/CONFIG_PACKAGE_xray-core=y/d' "$cfg"
        sed -i -e '/CONFIG_PACKAGE_sing-box=y/d' "$cfg"

        cat << 'EOF' >> "$cfg"
# Passwall
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y
# Passwall Binaries Selection (We use prebuilt, so we disable source compilation)
# CONFIG_PACKAGE_xray-core is not set
# CONFIG_PACKAGE_sing-box is not set
# CONFIG_PACKAGE_v2ray-core is not set
# CONFIG_PACKAGE_v2ray-plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy is not set
CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadow_TLS is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_tuic_client is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geoview is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y

# FTP 服务器 (vsftpd)
CONFIG_PACKAGE_luci-app-vsftpd=y
CONFIG_PACKAGE_luci-i18n-vsftpd-zh-cn=y
CONFIG_PACKAGE_vsftpd=y

# LUCKY (大吉)
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-i18n-lucky-zh-cn=y
CONFIG_PACKAGE_lucky=y
EOF
    fi
done



