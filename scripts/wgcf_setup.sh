#!/bin/bash

# 下载 wgcf
wget -q --show-progress https://github.com/ViRb3/wgcf/releases/download/v2.2.25/wgcf_2.2.25_linux_amd64

# 重命名
mv wgcf_2.2.25_linux_amd64 wgcf

# 赋予可执行权限
chmod +x wgcf

# 执行注册
./wgcf register

# 等待用户按回车键
read -p "按回车键继续..."

# 生成配置文件
./wgcf generate

# 读取 wgcf-profile.conf 中的关键信息
WGCF_CONF="/root/wgcf-profile.conf"

PRIVATE_KEY=$(grep -oP '(?<=PrivateKey = ).*' $WGCF_CONF)
PUBLIC_KEY=$(grep -oP '(?<=PublicKey = ).*' $WGCF_CONF)
ADDRESSES=$(grep -oP '(?<=Address = ).*' $WGCF_CONF)

# 分割 Address 字段并去掉前后空格
IFS=',' read -r ADDR_IPV4 ADDR_IPV6 <<< "$ADDRESSES"
ADDR_IPV4=$(echo "$ADDR_IPV4" | xargs)
ADDR_IPV6=$(echo "$ADDR_IPV6" | xargs)

# 替换 /etc/V2bX/route.json
cat > /etc/V2bX/route.json <<EOF
{
    "domainStrategy": "IPIfNonMatch",
    "rules": [
        {
            "type": "field",
            "domain": [
                "geosite:cn"
            ],
            "outboundTag": "wireguard-1"
        },
        {
            "type": "field",
            "ip": [
                "geoip:cn"
            ],
            "outboundTag": "wireguard-1"
        },
        {
            "type": "field",
            "outboundTag": "block",
            "ip": [
                "geoip:private"
            ]
        },
        {
            "type": "field",
            "outboundTag": "block",
            "ip": [
                "127.0.0.1/32",
                "10.0.0.0/8",
                "fc00::/7",
                "fe80::/10",
                "172.16.0.0/12"
            ]
        },
        {
            "type": "field",
            "outboundTag": "block",
            "protocol": [
                "bittorrent"
            ]
        }
    ]
}
EOF

# 替换 /etc/V2bX/custom_outbound.json
cat > /etc/V2bX/custom_outbound.json <<EOF
[
    {
        "tag": "IPv4_out",
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv4v6"
        }
    },
    {
        "tag": "IPv6_out",
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv6"
        }
    },
    {
        "protocol": "blackhole",
        "tag": "block"
    },
    {
        "protocol": "wireguard",
        "tag": "wireguard-1",
        "settings": {
            "secretKey": "$PRIVATE_KEY",
            "address": ["$ADDR_IPV4", "$ADDR_IPV6"],
            "peers": [
                {
                    "publicKey": "$PUBLIC_KEY",
                    "endpoint": "engage.cloudflareclient.com:2408"
                }
            ]
        }
    }
]
EOF

# 备份修改后的文件
mkdir -p /etc/v2back/
cp -p /etc/V2bX/route.json /etc/v2back/route.json.bak
cp -p /etc/V2bX/custom_outbound.json /etc/v2back/custom_outbound.json.bak

# 输出成功信息
echo "脚本执行完毕，配置已更新！并备份到/etc/v2back目录，请重启v2bx"
