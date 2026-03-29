#!/bin/bash

echo "☠️  正在执行终极操作：彻底消灭 nano 编辑器..."

# 找出 nano 所在位置
NANO_PATH=$(which nano 2>/dev/null)

# 如果存在就删除
if [ -n "$NANO_PATH" ] && [ -f "$NANO_PATH" ]; then
    echo "🔪 删除 nano 主程序: $NANO_PATH"
    rm -f "$NANO_PATH"
else
    echo "✅ 主程序已经不在了，真干净。"
fi

# 删除相关 man 手册和配置目录
echo "🧹 搜索 nano 相关文件并删除..."
for f in $(whereis -b nano | cut -d: -f2); do
    echo "🗑️  删除：$f"
    rm -rf "$f"
done

# 防止以后系统 update 自动装回来：用 vim 假冒 nano
if [ -f /usr/bin/vim ]; then
    echo "🕵️  用 vim 假扮 nano（软链接）..."
    ln -sf /usr/bin/vim /bin/nano
    echo "🎭 nano 其实是 vim 了！"
fi

# 设置系统默认编辑器为 vim
echo "🛠️  设置默认编辑器为 vim..."
update-alternatives --set editor /usr/bin/vim 2>/dev/null || echo "⚠️ 没有 alternatives 系统，跳过设置默认编辑器"

echo "✅ nano 已被彻底清除并伪装，任务完成，干净利落！"
