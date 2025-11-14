#!/bin/bash

# 闪电佛祖终端净化大师 · 修正版（避免重复显示佛祖）
# 适用于 root 用户执行

echo "⚡ 开始部署闪电佛祖护体终端..."

# Step 1. 清空并写入佛祖 MOTD
> /etc/motd
cat << 'EOF' > /etc/motd

   佛曰：代码如禅，Bug如劫，愿诸君静心编码，早日登顶。
   
          	 ⚡⚡⚡        	  ⚡⚡⚡
                        _oo0oo_
                       o8888888o
                       88" . "88
                       (| -_- |)
                       0\  =  /0
                     ___/`---'\___
                   .' \\|     |// '.
                  / \\|||  :  |||// \
                 / _||||| -:- |||||- \
                |   | \\\  -  /// |   |
                | \_|  ''\---/''  |_/ |
                \  .-\__  '-'  ___/-. /
              ___'. .'  /--.--\  `. .'___
           ."" '<  `.___\_<|>_/___.' >' "".
          | | :  `- \`.;`\ _ /`;.`/ - ` : | |
          \  \ `_.   \_ __\ /__ _/   .-` /  /
      =====`-.____`.___ \_____/___.-`___.-'=====
                        `=---='

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                佛祖保佑   永不宕机   永无 Bug

EOF

echo "✅ 佛祖已安坐 /etc/motd"

# Step 2. 禁用 update-motd.d 动态 MOTD 脚本
chmod -x /etc/update-motd.d/* 2>/dev/null || echo "⚠️ /etc/update-motd.d 不存在或为空"

# Step 3. 修改 PAM 配置，确保只显示 /etc/motd 的内容
PAM_FILE="/etc/pam.d/sshd"

# 精准注释掉含有动态 MOTD 的行（包含 motd=/run/motd.dynamic 和 noupdate）
sed -i '/motd=\/run\/motd\.dynamic/ s/^/# /' "$PAM_FILE"
sed -i '/noupdate/ s/^/# /' "$PAM_FILE"

# 同时，把所有其他 pam_motd.so 行（除了显示 /etc/motd 的）全部注释掉
sed -i '/pam_motd\.so/ { /motd=\/etc\/motd/! s/^/# / }' "$PAM_FILE"

# 注释掉所有 pam_lastlog.so 行
sed -i '/pam_lastlog\.so/ s/^/# /' "$PAM_FILE"

# 添加一行用于显示 /etc/motd（如果不存在）
if ! grep -E -q '^\s*session\s+optional\s+pam_motd\.so\s+motd=/etc/motd' "$PAM_FILE"; then
  echo "session optional pam_motd.so motd=/etc/motd" >> "$PAM_FILE"
  echo "✅ 已添加 pam_motd.so motd=/etc/motd"
else
  echo "ℹ️ pam_motd.so motd=/etc/motd 已存在，跳过添加"
fi

# Step 4. 修改 /etc/ssh/sshd_config 关闭 LastLogin 显示
SSHD_CONFIG="/etc/ssh/sshd_config"
if grep -qE '^\s*PrintLastLog\s+' "$SSHD_CONFIG"; then
  sed -i 's/^\s*PrintLastLog\s\+.*/PrintLastLog no/' "$SSHD_CONFIG"
  echo "✅ 已修改 sshd_config 中的 PrintLastLog 为 no"
else
  echo "PrintLastLog no" >> "$SSHD_CONFIG"
  echo "✅ 已添加 sshd_config 中的 PrintLastLog no"
fi

# Step 5. 询问是否重启 SSH 服务以使配置生效
read -p "🔁 是否现在重启 SSH 服务以生效？[y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  systemctl restart sshd && echo "✅ SSH 服务已重启，佛祖显灵！"
else
  echo "❗ 请稍后手动运行：systemctl restart sshd"
fi

echo "🎉 闪电佛祖部署完成！终端已净化，双佛归一已解，Bug 避让，运维加持！"
