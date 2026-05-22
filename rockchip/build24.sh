#!/bin/bash
# Log file for debugging
source shell/custom-packages.sh
source shell/switch_repository.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
# yml 传入的固件大小 ROOTFS_PARTSIZE
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # 下载 run 文件仓库
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/arm64 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/arm64/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
  # 添加架构优先级信息
  sed -i '1i\
  arch aarch64_generic 10\n\
  arch aarch64_cortex-a53 15' repositories.conf
fi


# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."
echo "查看repositories.conf信息——————"
cat repositories.conf
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""


packages=(
  luci-i18n-airplay2-zh-cn
  luci-i18n-openlist-zh-cn
  luci-app-argon-config
  luci-i18n-ddns-go-zh-cn
  luci-i18n-frpc-zh-cn
  luci-i18n-ttyd-zh-cn
  luci-i18n-vsftpd-zh-cn
  luci-i18n-wol-zh-cn
  luci-i18n-autoreboot-zh-cn
  luci-i18n-firewall-zh-cn
  luci-app-argon-config
  luci-i18n-argon-config-zh-cn
  luci-i18n-diskman-zh-cn
  luci-i18n-package-manager-zh-cn
  luci-i18n-ttyd-zh-cn
  luci-app-openclash
  luci-i18n-samba4-zh-cn
  openssh-sftp-server
  ppp-mod-pptp
  script-utils
  fdisk
  xl2tpd
  adb
  curl
  ntpdate
  usbutils
  python3
  python3-pip
  python3-requests  
  kmod-usb-core
  kmod-xfrm-interface
  kmod-ipsec
  kmod-ipsec4
  kmod-ipsec6
  iptables-mod-ipsec
  iptables-nft
  kmod-usb2
  kmod-usb3
  mt7601u-firmware
  wireguard-tools
  #kmod-usb-net-rtl8152
  kmod-usb-net-asix-ax88179
  kmod-usb-net-asix
  kmod-ath9k-htc
  kmod-mt76
  kmod-mt7601u
  kmod-mt76x0u
  kmod-mt76x2u
  kmod-mt7921u
  kmod-usb-ohci
  kmod-usb-uhci
  kmod-ata-ahci
  kmod-ata-core
  kmod-fs-ntfs
  kmod-fs-ext4
  kmod-usb-storage
  kmod-usb-storage-extras
  kmod-usb-serial
  kmod-usb-serial-pl2303
  kmod-usb-serial-ch341
  kmod-usb-printer
  kmod-usb-net-rndis
  kmod-i2c-core
  kmod-i2c-gpio
  kmod-spi-dev
  kmod-gpio-button-hotplug
  kmod-leds-gpio
  kmod-hid
  kmod-hid-generic
  kmod-sound-core
  kmod-usb-audio
)

# 使用循环逐个追加
for pkg in "${packages[@]}"; do
  PACKAGES="$PACKAGES $pkg"
done

# （可选）去重，防止重复包名
PACKAGES=$(echo "$PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')


# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    # Download latest openclash Client
    URL=$(curl -s https://api.github.com/repos/vernesong/OpenClash/releases/latest \
      | grep "browser_download_url.*ipk" \
      | head -n1 \
      | cut -d '"' -f 4)
    echo "OpenClash latest ipk: $URL"
    wget "$URL" -P /home/build/immortalwrt/packages/
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

if echo "$PACKAGES" | grep -q "luci-app-ssr-plus"; then
    echo "✅ 已选择 luci-app-ssr-plus，添加 mihomo core"
    mkdir -p files/usr/bin
    # Download mihomo
    MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.24/mihomo-linux-arm64-v1.19.24.gz"
    mkdir -p files/usr/bin
    wget -qO- "$MIHOMO_URL" | gzip -dc > files/usr/bin/mihomo
    chmod +x files/usr/bin/mihomo
    echo "✅ 已下载 mihomo core"
    ls -lah files/usr/bin
else
    echo "⚪️ 未选择 luci-app-ssr-plus"
fi


make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
