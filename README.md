# Python虚拟环境管理工具 (venv-manager)

一个用于在macOS上管理Python虚拟环境的命令行工具，支持venv、virtualenv和conda环境。

## 功能特点

- 自动检测并列出系统中所有的Python虚拟环境
- 支持多种虚拟环境类型：venv、virtualenv和conda
- 提供详细的环境信息，包括Python版本和已安装的包
- 简化创建和删除虚拟环境的过程
- 交互式菜单模式，方便新手使用
- 支持非交互式模式，适合脚本自动化

## 安装方法

1. 下载脚本文件：

```bash
curl -o venv-manager.sh https://raw.githubusercontent.com/manwallet/venv-manager/main/venv-manager.sh
```

2. 添加执行权限：

```bash
chmod +x venv-manager.sh
```

3. 可选：将脚本移动到PATH路径中，以便全局访问：

```bash
sudo mv venv-manager.sh /usr/local/bin/venv-manager
```

## 使用方法

### 交互式菜单模式

启动交互式菜单，适合新手用户：

```bash
./venv-manager.sh menu
```

或者直接运行脚本（默认启动菜单）：

```bash
./venv-manager.sh
```

### 命令行模式

#### 列出所有虚拟环境

```bash
./venv-manager.sh list
```

#### 查看特定环境的详细信息

```bash
./venv-manager.sh info myenv
```

#### 创建新的虚拟环境

基本用法：

```bash
./venv-manager.sh create myenv
```

指定Python版本：

```bash
./venv-manager.sh create myenv 3.9
```

指定环境类型：

```bash
./venv-manager.sh create myenv 3.9 conda
```

#### 删除虚拟环境

```bash
./venv-manager.sh delete myenv
```

强制删除（不提示确认）：

```bash
./venv-manager.sh delete myenv --force
```

## 命令参考

```
用法: ./venv-manager.sh [命令] [参数]

命令:
  list                列出所有虚拟环境
  info <环境名称>     显示指定虚拟环境的详细信息
  create <环境名称> [python版本] [类型]  创建新的虚拟环境
  delete <环境名称> [--force]   删除指定的虚拟环境
  menu                启动交互式菜单模式
  help                显示帮助信息

参数:
  --non-interactive     非交互式模式，不提示用户输入
  --force               强制执行操作，不提示确认
```

## 依赖项

- Python 3.x（必需）
- virtualenv（可选，用于创建virtualenv类型的环境）
- conda（可选，用于管理conda环境）

## 支持的环境位置

该工具会自动检测以下常见位置的虚拟环境：

- `~/.virtualenvs`（virtualenvwrapper默认目录）
- `~/venv`和`~/.venv`（常见自定义目录）
- `~/.local/share/virtualenvs`（pipenv默认目录）
- conda环境目录（包括用户和系统级安装）
- 项目本地的`venv`和`.venv`目录

## 许可证

MIT

## 作者

AI Code
