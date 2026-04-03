#!/bin/bash

# ==========================================
# 颜色定义，用于输出友好的提示信息
# ==========================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 打印带颜色的信息函数
info() { echo -e "${YELLOW}[*] $1${NC}"; }
success() { echo -e "${GREEN}[+] $1${NC}"; }
error() { echo -e "${RED}[-] $1${NC}"; }

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  error "错误: 请使用 root 权限运行此脚本 (可以使用 sudo bash)"
  exit 1
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}        Debian 自动建站脚本 (优化与可视化版)      ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""

# 1. 更新系统并安装必要工具包
info "正在检查并更新系统软件包..."
apt-get update -y > /dev/null 2>&1
success "系统软件包列表更新完成。"

info "正在安装必要工具 (curl, nginx, socat, openssl)..."
apt-get install -y curl nginx socat openssl > /dev/null 2>&1
if [ $? -eq 0 ]; then
    success "必要工具安装完成。"
else
    error "工具安装失败，请检查网络或 apt 源。"
    exit 1
fi

# 2. 交互提示输入域名
read -p "请输入你的域名 (例如 example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    error "域名不能为空！退出脚本。"
    exit 1
fi
success "当前配置域名: ${DOMAIN}"

# 3. 询问是否开启小云朵
echo ""
info "请问该域名是否在 Cloudflare 打开了小云朵 (代理)?"
echo "1) 是 (开启小云朵，需手动粘贴 CF 提供的源服务器证书)"
echo "2) 否 (不开启小云朵，使用 acme.sh 自动申请泛域名证书)"
read -p "请输入选项 [1 或 2]: " CF_PROXY_CHOICE

# 创建证书存放目录
mkdir -p /etc/nginx/ssl
info "确保证书存放目录 /etc/nginx/ssl 存在。"

if [ "$CF_PROXY_CHOICE" == "2" ]; then
    # 【不开启域名小云朵】的逻辑
    echo ""
    info "您选择了【不开启小云朵】，准备使用 acme.sh 申请证书。"
    info "【请粘贴 Cloudflare API 变量】"
    echo -e "请直接粘贴您的 export 变量。粘贴完成后，请在${RED}新的一行输入 EOF 并按回车键${NC}！"
    echo "示例格式:"
    echo 'export CF_Token="xxx"'
    echo 'export CF_Zone_ID="xxx"'
    echo 'export CF_Account_ID="xxx"'
    echo "------------------------------------------------"
    
    > /tmp/cf_api_tmp.sh
    while IFS= read -r line; do
        if [[ "$line" == "EOF" || "$line" == "eof" ]]; then
            break
        fi
        echo "$line" >> /tmp/cf_api_tmp.sh
    done
    
    # 加载环境变量
    source /tmp/cf_api_tmp.sh
    rm -f /tmp/cf_api_tmp.sh
    success "Cloudflare API 变量加载完毕。"

    # 安装 acme.sh (如果尚未安装)
    if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
        info "系统未检测到 acme.sh，正在执行自动安装..."
        curl https://get.acme.sh | sh > /dev/null 2>&1
        success "acme.sh 安装完成。"
    else
        success "系统已安装 acme.sh，跳过安装。"
    fi
    
    # 切换默认 CA 为 Let's Encrypt
    info "设置 acme.sh 默认 CA 为 Let's Encrypt..."
    $HOME/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1

    # 申请证书
    info "正在通过 Cloudflare DNS API 申请 ${DOMAIN} 的泛域名证书，这可能需要几分钟，请耐心等待..."
    $HOME/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN"

    if [ $? -eq 0 ]; then
        success "证书申请成功！"
    else
        error "证书申请失败，请检查您的 API 是否正确或域名 DNS 是否已生效。"
        exit 1
    fi

    # 安装证书到指定路径
    info "正在将证书提取并安装到 /etc/nginx/ssl/ 目录..."
    $HOME/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
        --key-file       /etc/nginx/ssl/${DOMAIN}.key  \
        --fullchain-file /etc/nginx/ssl/${DOMAIN}.cer \
        --reloadcmd     "systemctl reload nginx" > /dev/null 2>&1
    success "证书安装完成。"

elif [ "$CF_PROXY_CHOICE" == "1" ]; then
    # 【开启域名小云朵】的逻辑
    echo ""
    info "您选择了【开启小云朵】，请提供 Cloudflare 源服务器证书。"
    info "【请粘贴 Cloudflare 证书密钥 .key】"
    echo -e "粘贴完成后，请在${RED}新的一行输入 EOF 并按回车键${NC}："
    > /etc/nginx/ssl/${DOMAIN}.key
    while IFS= read -r line; do
        if [[ "$line" == "EOF" || "$line" == "eof" ]]; then
            break
        fi
        echo "$line" >> /etc/nginx/ssl/${DOMAIN}.key
    done
    success "密钥 (.key) 已保存至 /etc/nginx/ssl/${DOMAIN}.key"

    echo ""
    info "【请粘贴 Cloudflare 证书公钥 .cer / .pem】"
    echo -e "粘贴完成后，请在${RED}新的一行输入 EOF 并按回车键${NC}："
    > /etc/nginx/ssl/${DOMAIN}.cer
    while IFS= read -r line; do
        if [[ "$line" == "EOF" || "$line" == "eof" ]]; then
            break
        fi
        echo "$line" >> /etc/nginx/ssl/${DOMAIN}.cer
    done
    success "公钥 (.cer) 已保存至 /etc/nginx/ssl/${DOMAIN}.cer"
else
    error "无效的选择，退出脚本。"
    exit 1
fi

# 4. 创建网站目录
info "正在初始化网站根目录..."
mkdir -p /var/www/${DOMAIN}
chown -R www-data:www-data /var/www/${DOMAIN}
chmod -R 755 /var/www/${DOMAIN}
success "网站目录 /var/www/${DOMAIN} 创建并授权完毕。"

# 5. 自动探测 PHP-FPM 版本并生成 Nginx 配置
info "正在探测系统中的 PHP-FPM 环境..."
PHP_SOCK=$(find /run/php/ -name "php*-fpm.sock" 2>/dev/null | head -n 1)

# 满足用户需求：使用 .conf 作为配置文件后缀
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"

cat > ${NGINX_CONF} <<EOF
server {
    listen 80;
    server_name ${DOMAIN} *.${DOMAIN};
    # 强制跳转 HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN} *.${DOMAIN};

    # 证书路径
    ssl_certificate /etc/nginx/ssl/${DOMAIN}.cer;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;
    
    # 增强版 SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 网站根目录
    root /var/www/${DOMAIN};
    index index.html index.php index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
EOF

# 判断并写入静态或 PHP 规则
if [ -n "$PHP_SOCK" ]; then
    success "检测到 PHP-FPM 运行在: ${PHP_SOCK}，已自动写入 PHP 解析规则。"
    cat >> ${NGINX_CONF} <<EOF

    # PHP 解析配置
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }
EOF
    # 写一个探针测试页
    echo "<?php phpinfo(); ?>" > /var/www/${DOMAIN}/index.php
    chown www-data:www-data /var/www/${DOMAIN}/index.php
else
    info "系统未检测到 PHP-FPM 服务，已按纯静态网站进行配置。"
    # 写一个静态测试页
    echo "<h1>Welcome to ${DOMAIN}</h1><p>Static Nginx configured successfully.</p>" > /var/www/${DOMAIN}/index.html
    chown www-data:www-data /var/www/${DOMAIN}/index.html
fi

# 闭合 Nginx 配置文件
cat >> ${NGINX_CONF} <<EOF
}
EOF
success "Nginx 配置文件已生成: ${NGINX_CONF}"

# 启用该配置并重启 Nginx
info "正在建立软链接并测试 Nginx 语法..."
ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/
nginx -t

if [ $? -eq 0 ]; then
    success "Nginx 语法测试通过，正在重启 Nginx 服务..."
    systemctl restart nginx
    
    echo -e "\n${GREEN}==================================================${NC}"
    echo -e "${GREEN}  🎉 建站大功告成！${NC}"
    echo -e "  🌐 网站目录:   ${YELLOW}/var/www/${DOMAIN}${NC}"
    echo -e "  ⚙️  Nginx配置: ${YELLOW}${NGINX_CONF}${NC}"
    echo -e "  🔒 证书公钥:   ${YELLOW}/etc/nginx/ssl/${DOMAIN}.cer${NC}"
    echo -e "  🔑 证书私钥:   ${YELLOW}/etc/nginx/ssl/${DOMAIN}.key${NC}"
    echo -e "${GREEN}==================================================${NC}\n"
else
    error "Nginx 语法测试失败！配置文件可能存在问题，请运行 'nginx -t' 检查。"
fi
