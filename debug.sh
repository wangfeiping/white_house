#!/bin/bash
CHROOT_DIR="/chroot/ai"

debug_chroot() {
    echo "=== 开始 chroot 调试 ==="
    
    # 1. 检查系统信息
    echo "1. 系统信息:"
    uname -a
    echo ""
    
    # 2. 检查目录权限
    echo "2. 目录权限:"
    ls -ld $CHROOT_DIR
    echo ""
    
    # 3. 检查安全模块
    echo "3. 安全模块状态:"
    # AppArmor
    if command -v aa-status &> /dev/null; then
        echo "AppArmor: $(sudo aa-status | head -1)"
    fi
    # SELinux
    if command -v sestatus &> /dev/null; then
        echo "SELinux: $(sudo sestatus | grep "Current mode")"
    fi
    echo ""
    
    # 4. 检查内核参数
    echo "4. 相关内核参数:"
    sysctl kernel.grsecurity.chroot_deny_chmod 2>/dev/null || echo "grsecurity not found"
    sysctl kernel.grsecurity.chroot_deny_mknod 2>/dev/null || echo "grsecurity not found"
    echo ""
    
    # 5. 尝试不同的 chroot 方法
    echo "5. 测试不同的 chroot 方法:"
    
    echo "方法 A: 标准 chroot"
    sudo chroot $CHROOT_DIR /bin/bash -c "echo '标准 chroot 成功'" && echo "✓ 成功" || echo "✗ 失败"
    
    echo "方法 B: 使用 unshare"
    sudo unshare --root $CHROOT_DIR --mount --pid --fork /bin/bash -c "echo 'unshare 成功'" && echo "✓ 成功" || echo "✗ 失败"
    
    echo "方法 C: 使用 systemd-nspawn"
    if command -v systemd-nspawn &> /dev/null; then
        sudo systemd-nspawn -D $CHROOT_DIR /bin/bash -c "echo 'systemd-nspawn 成功'" && echo "✓ 成功" || echo "✗ 失败"
    else
        echo "systemd-nspawn 不可用"
    fi
}

debug_chroot

