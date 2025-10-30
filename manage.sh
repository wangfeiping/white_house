#!/bin/bash

# 隔离安全环境管理脚本
# 用法: manage.sh <操作> <用户名>

set -e

CHROOT_BASE="/chroot"

usage() {
    echo "用法: $0 <操作> <用户名>"
    echo "操作:"
    echo "  mount     - 挂载chroot文件系统"
    echo "  unmount   - 卸载chroot文件系统"
    echo "  update    - 更新chroot配置"
    echo "  remove    - 移除chroot安全隔离环境"
    echo "  status    - 检查chroot状态"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

OPERATION="$1"
USERNAME="$2"
CHROOT_DIR="$CHROOT_BASE/$USERNAME"

case "$OPERATION" in
    mount)
        echo "挂载chroot文件系统..."
        mount -t proc proc "$CHROOT_DIR/proc" 2>/dev/null || true
        mount --bind /dev "$CHROOT_DIR/dev" 2>/dev/null || true
        echo "完成"
        ;;
    unmount)
        echo "卸载chroot文件系统..."
        umount "$CHROOT_DIR/dev" 2>/dev/null || true
        umount "$CHROOT_DIR/proc" 2>/dev/null || true
        echo "完成"
        ;;
    update)
        echo "更新chroot配置..."
        cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"
        echo "完成"
        ;;
    remove)
        echo "移除chroot安全隔离环境..."
        read -p "确定要移除用户 $USERNAME 的chroot安全隔离环境吗? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            # 卸载文件系统
            umount "$CHROOT_DIR/dev" 2>/dev/null || true
            umount "$CHROOT_DIR/proc" 2>/dev/null || true
            
            # 恢复用户shell
            usermod -s /bin/bash "$USERNAME"
            
            # 移除SSH配置
            sed -i "/Match User $USERNAME/,+7d" /etc/ssh/sshd_config
            systemctl reload ssh
            
            # 移除目录
            rm -rf "$CHROOT_DIR"
            rm -f "/usr/local/bin/chroot_shell_$USERNAME"
            
            echo "chroot安全隔离环境已移除"
        else
            echo "操作取消"
        fi
        ;;
    status)
        echo "检查chroot状态..."
        if [[ -d "$CHROOT_DIR" ]]; then
            echo "✓ Chroot目录存在: $CHROOT_DIR"
            
            # 测试chroot
            if chroot "$CHROOT_DIR" /bin/bash -c "echo '✓'" &>/dev/null; then
                echo "✓ Chroot环境正常"
            else
                echo "✗ Chroot环境异常"
            fi
            
            # 检查用户shell
            user_shell=$(getent passwd "$USERNAME" | cut -d: -f7)
            if [[ "$user_shell" == "/usr/local/bin/chroot_shell_$USERNAME" ]]; then
                echo "✓ 用户shell配置正确"
            else
                echo "✗ 用户shell配置错误"
            fi
        else
            echo "✗ Chroot目录不存在"
        fi
        ;;
    *)
        usage
        ;;
esac

