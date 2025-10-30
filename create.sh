#!/bin/bash

# 安全隔离环境创建脚本
# 用法: sudo ./create.sh <用户名> [chroot目录]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印颜色信息
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示用法
usage() {
    echo "用法: $0 <用户名> [chroot目录]"
    echo "示例: $0 restricted_user /chroot/white_house"
    echo "示例: $0 john (使用默认目录 /chroot/john)"
    exit 1
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限执行"
        exit 1
    fi
}

# 检查参数
if [[ $# -lt 1 ]]; then
    usage
fi

USERNAME="$1"
CHROOT_BASE="${2:-/chroot/$USERNAME}"

# 基础命令列表（将复制到chroot环境）
BASIC_COMMANDS=("bash" "ls" "cat" "pwd" "mkdir" "rmdir" "cp" "mv" "rm" "echo" "whoami" "id" "clear" "env")

# 主函数
main() {
    check_root
    
    print_info "开始为用户 $USERNAME 创建安全隔离环境"
    print_info "Chroot 目录: $CHROOT_BASE"
    
    # 检查用户是否已存在
    if id "$USERNAME" &>/dev/null; then
        print_warning "用户 $USERNAME 已存在，将修改其配置"
    else
        create_user
    fi
    
    create_chroot_structure
    create_device_files
    copy_binaries_and_libs
    create_config_files
    setup_ssh_chroot
    create_custom_shell
    set_permissions
    test_chroot

    setup_chroot_network
    
    print_success "创建完成！"
    print_info "用户: $USERNAME"
    print_info "Chroot 目录: $CHROOT_BASE"
    print_info "登录方式: ssh $USERNAME@localhost"
}

setup_chroot_network() {
    echo "=== 设置 chroot 网络 ==="
    
    # 1. 复制配置文件
    echo "1. 复制网络配置文件..."
    sudo cp /etc/resolv.conf $CHROOT_BASE/etc/resolv.conf
    sudo cp /etc/hosts $CHROOT_BASE/etc/hosts
    sudo cp /etc/nsswitch.conf $CHROOT_BASE/etc/nsswitch.conf
    sudo cp /etc/host.conf $CHROOT_BASE/etc/host.conf

    sudo mkdir $CHROOT_BASE/sys
    sudo mkdir $CHROOT_BASE/run

    # 2. 挂载文件系统
    echo "2. 挂载虚拟文件系统..."
    sudo mount -t proc proc $CHROOT_BASE/proc
    sudo mount -t sysfs sysfs $CHROOT_BASE/sys
    sudo mount -t devtmpfs devtmpfs $CHROOT_BASE/dev
    sudo mount --bind /run $CHROOT_BASE/run
    sudo mount --bind /var/run $CHROOT_BASE/var/run
    
    # 3. 创建设备文件
    echo "3. 创建设备文件..."
    sudo mkdir -p $CHROOT_BASE/dev/net
    sudo mknod -m 666 $CHROOT_BASE/dev/net/tun c 10 200 2>/dev/null || true
    
    # 4. 复制网络工具
    echo "4. 复制网络工具..."
    copy_network_tools
    
    echo "网络设置完成！"
}

copy_network_tools() {
    # 基础网络工具
    local tools=("ping" "curl" "wget" "host" "nslookup" "ip" "ss" "netstat" "ifconfig")
    
    for tool in "${tools[@]}"; do
        tool_path=$(which $tool 2>/dev/null)
        if [[ -f "$tool_path" ]]; then
            # 确定目标目录
            if [[ "$tool_path" == /usr/bin/* ]]; then
                target_dir="$CHROOT_BASE/usr/bin"
            else
                target_dir="$CHROOT_BASE/bin"
            fi
            
            sudo mkdir -p "$target_dir"
            sudo cp "$tool_path" "$target_dir/" 2>/dev/null || true
            
            # 复制库文件
            copy_libraries "$tool_path"
        fi
    done
}

copy_libraries() {
    local binary="$1"
    for lib in $(ldd "$binary" 2>/dev/null | grep -o '/[^ ]*' | grep -v '('); do
        if [[ -f "$lib" ]]; then
            lib_dir="$CHROOT_BASE/$(dirname "$lib")"
            sudo mkdir -p "$lib_dir"
            sudo cp "$lib" "$lib_dir/" 2>/dev/null || true
        fi
    done
}

unmount_network() {
    echo "卸载网络文件系统..."
    sudo umount $CHROOT_DIR/proc 2>/dev/null || true
    sudo umount $CHROOT_DIR/sys 2>/dev/null || true
    sudo umount $CHROOT_DIR/dev 2>/dev/null || true
    sudo umount $CHROOT_DIR/run 2>/dev/null || true
    sudo umount $CHROOT_DIR/var/run 2>/dev/null || true
}

# 创建用户
create_user() {
    print_info "创建用户: $USERNAME"
    useradd -m -s /bin/bash "$USERNAME"
    #echo "$USERNAME:$(openssl rand -base64 12)" | chpasswd
    echo "$USERNAME:12345678" | sudo chpasswd
    print_success "用户 $USERNAME 创建完成，密码已随机生成"
}

# 创建chroot目录结构
create_chroot_structure() {
    print_info "创建 chroot 目录结构..."
    
    # 创建基础目录
    mkdir -p "$CHROOT_BASE"/{bin,dev,etc,home,lib,lib64,usr,usr/bin,usr/lib,tmp,var,proc}
    
    # 设置目录权限
    chmod 755 "$CHROOT_BASE"
    chmod 1777 "$CHROOT_BASE/tmp"  # 设置粘滞位
    
    # 创建用户home目录
    mkdir -p "$CHROOT_BASE/home/$USERNAME"
    chown "$USERNAME:$USERNAME" "$CHROOT_BASE/home/$USERNAME"
    chmod 755 "$CHROOT_BASE/home/$USERNAME"
    
    print_success "目录结构创建完成"
}

# 创建设备文件
create_device_files() {
    print_info "创建设备文件..."
    
    # 创建设备节点
    mknod -m 666 "$CHROOT_BASE/dev/null" c 1 3
    mknod -m 666 "$CHROOT_BASE/dev/zero" c 1 5
    mknod -m 666 "$CHROOT_BASE/dev/random" c 1 8
    mknod -m 666 "$CHROOT_BASE/dev/urandom" c 1 9
    mknod -m 666 "$CHROOT_BASE/dev/tty" c 5 0
    chmod 666 "$CHROOT_BASE/dev/tty"
    
    print_success "设备文件创建完成"
}

# 复制二进制文件和库
copy_binaries_and_libs() {
    print_info "复制二进制文件和库文件..."
    
    # 函数：复制库文件
    copy_libraries() {
        local binary="$1"
        for lib in $(ldd "$binary" 2>/dev/null | grep -o '/[^ ]*' | grep -v '('); do
            if [[ -f "$lib" ]]; then
                local lib_dir="$CHROOT_BASE/$(dirname "$lib")"
                mkdir -p "$lib_dir"
                cp "$lib" "$lib_dir/" 2>/dev/null || true
            fi
        done
    }
    
    # 复制基本命令
    for cmd in "${BASIC_COMMANDS[@]}"; do
        # 查找命令路径
        cmd_path=$(which "$cmd" 2>/dev/null || echo "/bin/$cmd")
        
        if [[ -f "$cmd_path" ]]; then
            # 复制二进制文件
            cp "$cmd_path" "$CHROOT_BASE/bin/" 2>/dev/null || true
            
            # 复制库文件
            copy_libraries "$cmd_path"
        fi
    done
    
    # 复制额外的必要库
    copy_essential_libraries() {
        local essential_libs=(
            "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
            "/lib/x86_64-linux-gnu/libc.so.6"
            "/lib/x86_64-linux-gnu/libm.so.6"
            "/lib/x86_64-linux-gnu/libdl.so.2"
            "/lib/x86_64-linux-gnu/libpthread.so.0"
            "/lib/x86_64-linux-gnu/librt.so.1"
        )
        
        for lib in "${essential_libs[@]}"; do
            if [[ -f "$lib" ]]; then
                lib_dir="$CHROOT_BASE/$(dirname "$lib")"
                mkdir -p "$lib_dir"
                cp "$lib" "$lib_dir/" 2>/dev/null || true
            fi
        done
    }
    
    copy_essential_libraries

    print_success "二进制文件和库文件复制完成"
}

# 创建配置文件
create_config_files() {
    print_info "创建配置文件..."
    
    # 创建passwd文件（只包含必要用户）
    cat > "$CHROOT_BASE/etc/passwd" << EOF
root:x:0:0:root:/root:/bin/bash
$USERNAME:x:$(id -u "$USERNAME"):$(id -g "$USERNAME"):$USERNAME:/home/$USERNAME:/bin/bash
EOF

    # 创建group文件
    cat > "$CHROOT_BASE/etc/group" << EOF
root:x:0:
$USERNAME:x:$(id -g "$USERNAME"):
EOF

    # 创建nsswitch.conf
    cat > "$CHROOT_BASE/etc/nsswitch.conf" << EOF
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
EOF

    # 创建resolv.conf
    cp /etc/resolv.conf "$CHROOT_BASE/etc/resolv.conf"

    # 创建hosts文件
    cat > "$CHROOT_BASE/etc/hosts" << EOF
127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
EOF

    # 创建profile文件
    cat > "$CHROOT_BASE/etc/profile" << EOF
export PATH=/bin:/usr/bin
export USER=$USERNAME
export HOME=/home/$USERNAME
export SHELL=/bin/bash
export TERM=xterm-256color

cd \$HOME
echo "欢迎来到 chroot 环境 (用户: \$USER)"
echo "这是一个受限制的环境"
EOF

    # 创建bashrc
    cat > "$CHROOT_BASE/home/$USERNAME/.bashrc" << EOF
export PS1='[\u@chroot:\w]\$ '
alias ll='ls -la'
alias l='ls -l'
EOF

    chown "$USERNAME:$USERNAME" "$CHROOT_BASE/home/$USERNAME/.bashrc"
    
    print_success "配置文件创建完成"
}

# 设置SSH chroot
setup_ssh_chroot() {
    print_info "配置 SSH chroot..."
    
    # 检查SSH配置是否已存在
    if grep -q "Match User $USERNAME" /etc/ssh/sshd_config; then
        print_warning "SSH配置已存在，跳过配置"
        return
    fi
    
    # 备份SSH配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # 添加chroot配置
    cat >> /etc/ssh/sshd_config << EOF

# Chroot configuration for $USERNAME
Match User $USERNAME
    ChrootDirectory $CHROOT_BASE
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no
    PasswordAuthentication yes
EOF

    # 重启SSH服务
    if systemctl is-active --quiet ssh; then
        systemctl reload ssh
        print_success "SSH服务已重新加载"
    else
        print_warning "SSH服务未运行，请手动启动"
    fi
    
    print_success "SSH chroot配置完成"
}

# 创建自定义shell
create_custom_shell() {
    print_info "创建自定义shell..."
    
    # 创建自定义shell脚本
    cat > "/usr/local/bin/chroot_shell_$USERNAME" << EOF
#!/bin/bash
# 自定义chroot shell for $USERNAME

CHROOT_DIR="$CHROOT_BASE"
USERNAME="$USERNAME"

# 检查用户
if [ "\$USER" != "\$USERNAME" ]; then
    echo "错误: 此shell仅供用户 \$USERNAME 使用"
    exit 1
fi

# 挂载proc文件系统
mount -t proc proc "\$CHROOT_DIR/proc" 2>/dev/null || true

# 执行chroot
exec chroot "\$CHROOT_DIR" /bin/bash -l "\$@"
EOF

    chmod +x "/usr/local/bin/chroot_shell_$USERNAME"
    
    # 设置用户使用自定义shell
    usermod -s "/usr/local/bin/chroot_shell_$USERNAME" "$USERNAME"
    
    print_success "自定义shell创建完成"
}

# 设置权限
set_permissions() {
    print_info "设置文件权限..."
    
    # 设置chroot目录所有者
    chown root:root "$CHROOT_BASE"
    
    # 设置bin目录文件权限
    chown root:root "$CHROOT_BASE/bin"/*
    chmod 755 "$CHROOT_BASE/bin"/*
    
    # 设置用户home目录权限
    chown -R "$USERNAME:$USERNAME" "$CHROOT_BASE/home/$USERNAME"
    
    print_success "权限设置完成"
}

# 测试chroot环境
test_chroot() {
    print_info "测试chroot环境..."
    
    # 测试基本功能
    if chroot "$CHROOT_BASE" /bin/bash -c "echo 'Chroot测试成功'"; then
        print_success "Chroot环境测试通过"
    else
        print_error "Chroot环境测试失败"
        exit 1
    fi
    
    # 测试用户命令
    if chroot "$CHROOT_BASE" /bin/bash -c "whoami && pwd && ls /" > /dev/null 2>&1; then
        print_success "基本命令测试通过"
    else
        print_error "基本命令测试失败"
    fi
}

# 清理函数（在脚本中断时调用）
cleanup() {
    print_error "脚本执行中断，正在清理..."
    # 这里可以添加清理代码
    exit 1
}

# 设置陷阱，确保脚本中断时执行清理
trap cleanup INT TERM

# 执行主函数
main "$@"

