#!/bin/bash

# echo "[password]" | sudo -S [command]

fix_pty_system() {
    echo "=== 修复系统 PTY 错误 ==="
    
    # 1. 检查系统状态
    echo "1. 检查系统状态..."
    check_system_status
    
    # 2. 修复设备文件
    echo "2. 修复设备文件..."
    fix_device_files
    
    # 3. 重新挂载文件系统
    echo "3. 重新挂载文件系统..."
    remount_filesystems
    
    # 4. 验证修复
    echo "4. 验证修复..."
    verify_fix
    
    echo "修复完成！"
}

check_system_status() {
    # 检查内核消息
    echo "检查内核消息..."
    dmesg | grep -i pty | tail -5
    
    # 检查可用 PTY
    echo "检查可用 PTY 数量..."
    ls /dev/pts/ | wc -l
}

fix_device_files() {
    # 确保设备目录存在
    sudo mkdir -p /dev/pts
    
    # 重新创建设备文件
    sudo rm -f /dev/ptmx
    sudo mknod -m 666 /dev/ptmx c 5 2
    
    sudo rm -f /dev/tty
    sudo mknod -m 666 /dev/tty c 5 0
    
    # 设置正确的权限
    sudo chmod 666 /dev/ptmx
    sudo chmod 666 /dev/tty
}

remount_filesystems() {
    # 卸载并重新挂载 devpts
    echo "重新挂载 devpts..."
    sudo umount /dev/pts 2>/dev/null || true
    sudo mount -t devpts devpts /dev/pts -o gid=5,mode=620,nosuid,noexec
    
    # 检查其他相关文件系统
    sudo mount -o remount /dev
    sudo mount -o remount /proc
}

verify_fix() {
    echo "验证修复结果..."
    
    # 测试 tty 命令
    if tty > /dev/null 2>&1; then
        echo "✓ tty 命令正常工作"
    else
        echo "✗ tty 命令仍然失败"
    fi
    
    # 测试打开新终端
    if script -c "echo '测试'" /dev/null > /dev/null 2>&1; then
        echo "✓ 可以创建新终端"
    else
        echo "✗ 创建新终端失败"
    fi
    
    # 检查设备文件
    if [ -c /dev/ptmx ] && [ -c /dev/tty ]; then
        echo "✓ 设备文件存在且类型正确"
    else
        echo "✗ 设备文件问题"
    fi
}

# 执行修复
fix_pty_system

