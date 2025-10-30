# White House

Security Isolation Environment Management Tools

提供了完整的创建和管理功能，具有以下特点：

通过参数指定用户名

自动创建目录结构和配置文件

复制必要的二进制文件和库

配置SSH chroot访问

创建自定义shell

完整的错误处理和颜色输出

配套的管理脚本

## 设置执行权限
sudo chmod +x /usr/local/bin/create.sh

## 使用方法1：使用默认chroot目录
sudo /usr/local/bin/create.sh restricted_user

## 使用方法2：指定chroot目录
sudo /usr/local/bin/create.sh restricted_user /chroot/white_house

## 使用方法3：创建多个用户
sudo /usr/local/bin/create.sh user1  
sudo /usr/local/bin/create.sh user2 /chroot/user2_white_house  

## 创建
sudo create.sh test_user

## 管理
sudo manage.sh status test_user  
sudo manage.sh update test_user  
sudo manage.sh mount test_user  

## 测试连接
ssh test_user@localhost

## 移除（如果需要）
sudo manage.sh remove test_user

## 測試驗證

### 测试SSH连接
ssh restricted_chroot@localhost

### 或者在本地测试
sudo su - restricted_chroot  
sudo chroot /chroot/white_house /bin/bash  

### 检查chroot环境完整性
sudo chroot /chroot/restricted_user /bin/bash -c "echo 'Chroot test successful'"

### 检查缺少的库文件
sudo chroot /chroot/restricted_user /bin/bash -c "ldd /bin/ls"

### 查看系统日志
sudo journalctl -f

# 检查 chroot 环境是否完整
sudo ls -la /chroot/ai/  
sudo tree /chroot/ai/ -L 2  


