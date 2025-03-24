#!/bin/bash
# venv-manager.sh - 管理macOS上的Python虚拟环境的工具
# 作者: AI Code
# 版本： 1.0.1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 全局变量
HAS_VIRTUALENV=true
HAS_CONDA=true
NON_INTERACTIVE=false  # 是否为非交互式模式

# 帮助信息
show_help() {
    echo -e "${BLUE}venv-manager${NC} - macOS Python虚拟环境管理工具"
    echo
    echo -e "用法: ${GREEN}./venv-manager.sh${NC} ${YELLOW}[命令]${NC} ${CYAN}[参数]${NC}"
    echo
    echo -e "命令:"
    echo -e "  ${YELLOW}list${NC}                列出所有虚拟环境"
    echo -e "  ${YELLOW}info${NC} ${CYAN}<环境名称>${NC}     显示指定虚拟环境的详细信息"
    echo -e "  ${YELLOW}create${NC} ${CYAN}<环境名称>${NC} ${CYAN}[python版本]${NC} ${CYAN}[类型]${NC}  创建新的虚拟环境"
    echo -e "  ${YELLOW}delete${NC} ${CYAN}<环境名称>${NC} ${CYAN}[--force]${NC}   删除指定的虚拟环境"
    echo -e "  ${YELLOW}menu${NC}                启动交互式菜单模式"
    echo -e "  ${YELLOW}help${NC}                显示此帮助信息"
    echo
    echo -e "参数:"
    echo -e "  ${CYAN}--non-interactive${NC}     非交互式模式，不提示用户输入"
    echo -e "  ${CYAN}--force${NC}               强制执行操作，不提示确认"
    echo
    echo -e "示例:"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}list${NC}"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}info${NC} ${CYAN}myenv${NC}"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}create${NC} ${CYAN}myenv${NC} ${CYAN}3.9${NC} ${CYAN}venv${NC}"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}create${NC} ${CYAN}myenv${NC} ${CYAN}--non-interactive${NC}"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}delete${NC} ${CYAN}myenv${NC} ${CYAN}--force${NC}"
    echo -e "  ${GREEN}./venv-manager.sh${NC} ${YELLOW}menu${NC}                # 启动交互式菜单"
    echo
}

# 检查依赖
check_dependencies() {
    local critical_missing=false
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误: 未安装Python3，这是必需的依赖${NC}"
        echo -e "请安装Python3后再运行此脚本。"
        exit 1
    fi
    
    # 检查virtualenv (可选)
    if ! python3 -m pip show virtualenv &> /dev/null; then
        echo -e "${YELLOW}注意: virtualenv未安装，某些功能将不可用${NC}"
        echo -e "建议: ${CYAN}pip install virtualenv${NC} 以启用所有功能"
        HAS_VIRTUALENV=false
    else
        HAS_VIRTUALENV=true
    fi
    
    # 检查conda (可选)
    if ! command -v conda &> /dev/null; then
        echo -e "${YELLOW}注意: conda未安装，将不支持conda环境管理${NC}"
        HAS_CONDA=false
    else
        HAS_CONDA=true
    fi
}

# 获取虚拟环境目录
get_venv_dirs() {
    local venv_dirs=()
    
    # 检查常见的venv目录
    local common_dirs=(
        "$HOME/.virtualenvs"      # virtualenvwrapper默认目录
        "$HOME/venv"              # 常见自定义目录
        "$HOME/.venv"             # 常见隐藏目录
        "$HOME/.local/share/virtualenvs"  # pipenv默认目录
        "$HOME/anaconda3/envs"    # 用户目录下的conda
        "$HOME/miniconda3/envs"   # 用户目录下的miniconda
        "$HOME/opt/anaconda3/envs" # macOS Homebrew安装的conda
        "$HOME/opt/miniconda3/envs" # macOS Homebrew安装的miniconda
        "/opt/anaconda3/envs"     # 系统级安装的conda
        "/opt/miniconda3/envs"    # 系统级安装的miniconda
        "/usr/local/anaconda3/envs" # 另一个常见的系统级安装位置
        "/usr/local/miniconda3/envs" # 另一个常见的系统级安装位置
        "./venv"                  # 项目本地venv
        "./.venv"                 # 项目本地隐藏venv
    )
    
    for dir in "${common_dirs[@]}"; do
        if [ -d "$dir" ]; then
            venv_dirs+=("$dir")
        fi
    done
    
    # 如果安装了conda，添加conda环境目录
    if command -v conda &> /dev/null; then
        # 获取conda基础目录
        local conda_base=$(conda info --base 2>/dev/null)
        if [ -d "${conda_base}/envs" ]; then
            venv_dirs+=("${conda_base}/envs")
        fi
        
        # 检查conda当前环境
        local current_env=$(conda info --envs 2>/dev/null | grep "*" | awk '{print $1}')
        if [ -n "$current_env" ] && [ "$current_env" != "base" ]; then
            # 当前激活的非base环境
            local env_path=$(conda info --envs 2>/dev/null | grep "*" | awk '{print $2}')
            if [ -d "$env_path" ] && [[ ! " ${venv_dirs[@]} " =~ " ${env_path%/*} " ]]; then
                venv_dirs+=("${env_path%/*}")  # 添加父目录
            fi
        fi
    fi
    
    echo "${venv_dirs[@]}"
}

# 列出所有虚拟环境
list_environments() {
    echo -e "${BLUE}=== Python虚拟环境列表 ===${NC}"
    
    local venv_dirs=($(get_venv_dirs))
    local found=false
    
    # 列出venv/virtualenv环境
    for dir in "${venv_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}目录: ${dir}${NC}"
            local count=0
            
            # 遍历目录中的所有子目录
            for venv in "$dir"/*; do
                if [ -d "$venv" ]; then
                    # 检查是否是有效的虚拟环境
                    if [ -f "$venv/pyvenv.cfg" ] || [ -d "$venv/bin" ] || [ -d "$venv/Scripts" ]; then
                        local venv_name=$(basename "$venv")
                        local python_path=""
                        local python_version=""
                        
                        # 尝试获取Python路径和版本
                        if [ -f "$venv/bin/python" ]; then
                            python_path="$venv/bin/python"
                        elif [ -f "$venv/Scripts/python.exe" ]; then
                            python_path="$venv/Scripts/python.exe"
                        fi
                        
                        if [ -n "$python_path" ]; then
                            python_version=$("$python_path" --version 2>&1 | cut -d' ' -f2)
                        else
                            python_version="未知"
                        fi
                        
                        echo -e "  ${GREEN}$venv_name${NC} (Python $python_version)"
                        count=$((count+1))
                        found=true
                    fi
                fi
            done
            
            if [ $count -eq 0 ]; then
                echo -e "  ${CYAN}没有发现虚拟环境${NC}"
            fi
            echo
        fi
    done
    
    # 列出conda环境
    if command -v conda &> /dev/null; then
        echo -e "${YELLOW}Conda环境:${NC}"
        # 使用--json格式获取更可靠的环境列表
        if conda --version 2>/dev/null | grep -q "conda 4"; then
            # conda 4.x 支持--json选项
            local conda_envs=$(conda env list --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for env in data.get('envs', []):
        name = env.split('/')[-1]
        if name == 'envs':  # 跳过envs目录本身
            continue
        print(f'{name} {env}')
except:
    pass
")
            if [ -n "$conda_envs" ]; then
                echo "$conda_envs" | while read -r line; do
                    env_name=$(echo "$line" | awk '{print $1}')
                    env_path=$(echo "$line" | cut -d' ' -f2-)
                    
                    # 检查是否是当前激活的环境
                    if [ "$CONDA_DEFAULT_ENV" = "$env_name" ]; then
                        echo -e "  ${GREEN}$env_name${NC} (已激活) - $env_path"
                    else
                        echo -e "  ${CYAN}$env_name${NC} - $env_path"
                    fi
                    found=true
                done
            fi
        else
            # 回退到传统方式
            conda env list 2>/dev/null | grep -v "^#" | while read -r line; do
                if [[ $line == *"*"* ]]; then
                    # 当前激活的环境
                    env_name=$(echo "$line" | awk '{print $1}')
                    env_path=$(echo "$line" | awk '{print $2}')
                    echo -e "  ${GREEN}$env_name${NC} (已激活) - $env_path"
                else
                    env_name=$(echo "$line" | awk '{print $1}')
                    env_path=$(echo "$line" | awk '{print $2}')
                    echo -e "  ${CYAN}$env_name${NC} - $env_path"
                fi
                found=true
            done
        fi
        echo
    fi
    
    # 检查系统级conda安装
    if [ -d "/opt/anaconda3" ] && [ ! -x "$(command -v conda)" ]; then
        echo -e "${YELLOW}系统级Conda安装：${NC}"
        echo -e "  ${CYAN}发现系统级Anaconda安装在 /opt/anaconda3${NC}"
        echo -e "  ${YELLOW}提示: 使用 ${GREEN}source /opt/anaconda3/bin/activate${NC} 激活base环境${NC}"
        found=true
        echo
    fi
    
    if [ "$found" = false ]; then
        echo -e "${RED}未找到任何Python虚拟环境。${NC}"
        echo -e "您可以使用 ${GREEN}./venv-manager.sh create <环境名称>${NC} 创建一个新环境。"
    fi
}

# 显示虚拟环境详细信息
show_environment_info() {
    local env_name="$1"
    
    if [ -z "$env_name" ]; then
        echo -e "${RED}错误: 未指定环境名称${NC}"
        echo -e "用法: ${GREEN}./venv-manager.sh${NC} ${YELLOW}info${NC} ${CYAN}<环境名称>${NC}"
        return 1
    fi
    
    local venv_dirs=($(get_venv_dirs))
    local env_path=""
    local env_type=""
    
    # 查找环境路径
    for dir in "${venv_dirs[@]}"; do
        if [ -d "$dir/$env_name" ]; then
            env_path="$dir/$env_name"
            env_type="venv/virtualenv"
            break
        fi
    done
    
    # 如果没找到，检查是否是conda环境
    if [ -z "$env_path" ] && command -v conda &> /dev/null; then
        local conda_info=$(conda env list 2>/dev/null | grep "^$env_name ")
        if [ -n "$conda_info" ]; then
            env_path=$(echo "$conda_info" | awk '{print $2}')
            env_type="conda"
        fi
    fi
    
    if [ -z "$env_path" ]; then
        echo -e "${RED}错误: 未找到名为 '$env_name' 的虚拟环境${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== 虚拟环境详细信息 ===${NC}"
    echo -e "${YELLOW}名称:${NC} $env_name"
    echo -e "${YELLOW}类型:${NC} $env_type"
    echo -e "${YELLOW}路径:${NC} $env_path"
    
    local python_path=""
    local python_version=""
    
    # 获取Python路径和版本
    if [ "$env_type" = "venv/virtualenv" ]; then
        if [ -f "$env_path/bin/python" ]; then
            python_path="$env_path/bin/python"
        elif [ -f "$env_path/Scripts/python.exe" ]; then
            python_path="$env_path/Scripts/python.exe"
        fi
    elif [ "$env_type" = "conda" ]; then
        python_path="$(conda run -n "$env_name" which python 2>/dev/null)"
    fi
    
    if [ -n "$python_path" ]; then
        python_version=$("$python_path" --version 2>&1)
        echo -e "${YELLOW}Python:${NC} $python_version"
        echo -e "${YELLOW}解释器:${NC} $python_path"
        
        # 显示已安装的包
        echo -e "\n${BLUE}已安装的包:${NC}"
        if [ "$env_type" = "venv/virtualenv" ]; then
            "$python_path" -m pip list 2>/dev/null | awk 'NR>2 {printf "  %s %s\n", $1, $2}'
        elif [ "$env_type" = "conda" ]; then
            conda list -n "$env_name" 2>/dev/null | awk 'NR>3 {printf "  %s %s\n", $1, $2}'
        fi
    else
        echo -e "${RED}无法找到Python解释器${NC}"
    fi
}

# 创建新的虚拟环境
create_environment() {
    local env_name="$1"
    local python_version="$2"
    local env_type="$3"  # 可选参数：venv, virtualenv, conda
    
    if [ -z "$env_name" ]; then
        echo -e "${RED}错误： 未指定环境名称${NC}"
        echo -e "用法： ${GREEN}./venv-manager.sh${NC} ${YELLOW}create${NC} ${CYAN}<环境名称>${NC} ${CYAN}[python版本]${NC} ${CYAN}[类型]${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== 创建新的虚拟环境 ===${NC}"
    echo -e "${YELLOW}名称:${NC} $env_name"
    
    local create_option=""
    local venv_dir="$HOME/.virtualenvs"
    # 确保目录存在
    mkdir -p "$venv_dir"
    
    # 如果指定了环境类型，直接使用
    if [ -n "$env_type" ]; then
        case "$env_type" in
            venv)
                create_option="1"
                ;;
            virtualenv)
                if [ "$HAS_VIRTUALENV" = true ]; then
                    create_option="2"
                else
                    echo -e "${RED}错误: virtualenv未安装，无法使用此方式创建环境${NC}"
                    return 1
                fi
                ;;
            conda)
                if [ "$HAS_CONDA" = true ]; then
                    create_option="3"
                else
                    echo -e "${RED}错误: conda未安装，无法使用此方式创建环境${NC}"
                    return 1
                fi
                ;;
            *)
                echo -e "${RED}错误: 无效的环境类型 '$env_type'${NC}"
                echo -e "有效的环境类型: venv, virtualenv, conda"
                return 1
                ;;
        esac
    # 如果是非交互式模式且未指定类型，默认使用venv
    elif [ "$NON_INTERACTIVE" = true ]; then
        create_option="1"
        echo -e "${YELLOW}非交互式模式： 默认使用venv创建环境${NC}"
    # 交互式模式下询问用户
    else
        echo -e "${CYAN}请选择创建方式:${NC}"
        echo -e "  ${GREEN}1)${NC} venv (Python内置)"
        
        if [ "$HAS_VIRTUALENV" = true ]; then
            echo -e "  ${GREEN}2)${NC} virtualenv"
        fi
        
        if [ "$HAS_CONDA" = true ]; then
            echo -e "  ${GREEN}3)${NC} conda"
        fi
        
        read -p "请输入选项 [1-3]: " create_option
    fi
    
    case $create_option in
        1)
            echo -e "${CYAN}使用venv创建环境...${NC}"
            if [ -n "$python_version" ]; then
                echo -e "${YELLOW}注意: venv不支持指定Python版本，将使用当前的Python版本${NC}"
            fi
            python3 -m venv "$venv_dir/$env_name"
            ;;
        2)
            if [ "$HAS_VIRTUALENV" = true ]; then
                echo -e "${CYAN}使用virtualenv创建环境...${NC}"
                if [ -n "$python_version" ]; then
                    python3 -m virtualenv -p "python$python_version" "$venv_dir/$env_name"
                else
                    python3 -m virtualenv "$venv_dir/$env_name"
                fi
            else
                echo -e "${RED}错误: virtualenv未安装${NC}"
                echo -e "请使用 ${CYAN}pip install virtualenv${NC} 安装后再试"
                return 1
            fi
            ;;
        3)
            if [ "$HAS_CONDA" = true ]; then
                echo -e "${CYAN}使用conda创建环境...${NC}"
                if [ -n "$python_version" ]; then
                    conda create -y -n "$env_name" python="$python_version"
                else
                    conda create -y -n "$env_name" python
                fi
            else
                echo -e "${RED}错误: conda未安装${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}错误: 无效的选项${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}虚拟环境 '$env_name' 创建成功！${NC}"
        echo -e "可以使用以下命令激活环境:"
        
        if [ "$create_option" = "3" ]; then
            echo -e "  ${CYAN}conda activate $env_name${NC}"
        else
            echo -e "  ${CYAN}source $venv_dir/$env_name/bin/activate${NC}"
        fi
    else
        echo -e "${RED}创建虚拟环境失败${NC}"
        return 1
    fi
}

# 删除虚拟环境
delete_environment() {
    local env_name="$1"
    local force_delete="$2"
    
    if [ -z "$env_name" ]; then
        echo -e "${RED}错误： 未指定环境名称${NC}"
        echo -e "用法: ${GREEN}./venv-manager.sh${NC} ${YELLOW}delete${NC} ${CYAN}<环境名称>${NC} ${CYAN}[--force]${NC}"
        return 1
    fi
    
    local venv_dirs=($(get_venv_dirs))
    local env_path=""
    local env_type=""
    
    # 查找环境路径
    for dir in "${venv_dirs[@]}"; do
        if [ -d "$dir/$env_name" ]; then
            env_path="$dir/$env_name"
            env_type="venv/virtualenv"
            break
        fi
    done
    
    # 如果没找到，检查是否是conda环境
    if [ -z "$env_path" ] && command -v conda &> /dev/null; then
        local conda_info=$(conda env list 2>/dev/null | grep "^$env_name ")
        if [ -n "$conda_info" ]; then
            env_path=$(echo "$conda_info" | awk '{print $2}')
            env_type="conda"
        fi
    fi
    
    if [ -z "$env_path" ]; then
        echo -e "${RED}错误: 未找到名为 '$env_name' 的虚拟环境${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}警告: 即将删除虚拟环境 '$env_name'${NC}"
    echo -e "${YELLOW}路径: $env_path${NC}"
    
    # 如果是强制删除或非交互式模式，直接删除
    if [ "$force_delete" = "--force" ] || [ "$NON_INTERACTIVE" = true ]; then
        echo -e "${YELLOW}执行强制删除...${NC}"
        confirm="y"
    else
        read -p "确定要删除吗? [y/N] " confirm
    fi
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [ "$env_type" = "venv/virtualenv" ]; then
            rm -rf "$env_path"
        elif [ "$env_type" = "conda" ]; then
            conda env remove -n "$env_name" -y
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}虚拟环境 '$env_name' 已成功删除${NC}"
        else
            echo -e "${RED}删除虚拟环境失败${NC}"
            return 1
        fi
    else
        echo -e "${CYAN}已取消删除操作${NC}"
    fi
}

# 检查参数中是否包含指定标志
has_flag() {
    local flag="$1"
    shift
    local args=("$@")
    
    for arg in "${args[@]}"; do
        if [ "$arg" = "$flag" ]; then
            return 0
        fi
    done
    
    return 1
}

# 显示交互式菜单
show_menu() {
    clear
    echo -e "${BLUE}===== Python虚拟环境管理工具 =====${NC}"
    echo
    echo -e "${GREEN}1)${NC} 列出所有虚拟环境"
    echo -e "${GREEN}2)${NC} 查看环境详细信息"
    echo -e "${GREEN}3)${NC} 创建新环境"
    echo -e "${GREEN}4)${NC} 删除环境"
    echo -e "${GREEN}0)${NC} 退出"
    echo
    read -p "请选择操作 [0-4]: " choice
    
    case $choice in
        1)
            list_environments
            echo
            read -p "按回车键继续..."
            show_menu
            ;;
        2)
            echo
            # 获取环境列表
            local env_list=()
            local env_count=0
            
            # 从venv/virtualenv目录获取环境
            local venv_dirs=($(get_venv_dirs))
            for dir in "${venv_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    for venv in "$dir"/*; do
                        if [ -d "$venv" ] && { [ -f "$venv/pyvenv.cfg" ] || [ -d "$venv/bin" ] || [ -d "$venv/Scripts" ]; }; then
                            local venv_name=$(basename "$venv")
                            env_list+=("$venv_name")
                            env_count=$((env_count+1))
                            echo -e "${GREEN}$env_count)${NC} $venv_name"
                        fi
                    done
                fi
            done
            
            # 从conda获取环境
            if command -v conda &> /dev/null; then
                conda env list 2>/dev/null | grep -v "^#" | while read -r line; do
                    env_name=$(echo "$line" | awk '{print $1}')
                    if [ "$env_name" != "base" ]; then
                        env_list+=("$env_name")
                        env_count=$((env_count+1))
                        echo -e "${GREEN}$env_count)${NC} $env_name"
                    fi
                done
            fi
            
            if [ $env_count -eq 0 ]; then
                echo -e "${YELLOW}未找到任何虚拟环境${NC}"
                read -p "按回车键继续..."
                show_menu
            else
                echo
                read -p "请选择环境 [1-$env_count]: " env_choice
                
                if [[ $env_choice =~ ^[0-9]+$ ]] && [ $env_choice -ge 1 ] && [ $env_choice -le $env_count ]; then
                    local selected_env="${env_list[$env_choice-1]}"
                    show_environment_info "$selected_env"
                    echo
                    read -p "按回车键继续..."
                else
                    echo -e "${RED}无效的选择${NC}"
                    sleep 1
                fi
                show_menu
            fi
            ;;
        3)
            echo
            read -p "请输入新环境名称: " env_name
            
            if [ -z "$env_name" ]; then
                echo -e "${RED}错误: 环境名称不能为空${NC}"
                sleep 1
                show_menu
            fi
            
            read -p "请输入Python版本 (可选，直接回车跳过): " python_version
            
            echo -e "${CYAN}请选择创建方式:${NC}"
            echo -e "  ${GREEN}1)${NC} venv (Python内置)"
            
            if [ "$HAS_VIRTUALENV" = true ]; then
                echo -e "  ${GREEN}2)${NC} virtualenv"
            fi
            
            if [ "$HAS_CONDA" = true ]; then
                echo -e "  ${GREEN}3)${NC} conda"
            fi
            
            read -p "请选择 [1-3]: " create_type
            
            case $create_type in
                1) env_type="venv" ;;
                2) env_type="virtualenv" ;;
                3) env_type="conda" ;;
                *) 
                    echo -e "${RED}无效的选择，默认使用venv${NC}"
                    env_type="venv"
                    sleep 1
                    ;;
            esac
            
            create_environment "$env_name" "$python_version" "$env_type"
            echo
            read -p "按回车键继续..."
            show_menu
            ;;
        4)
            echo
            # 获取环境列表
            local env_list=()
            local env_count=0
            
            # 从venv/virtualenv目录获取环境
            local venv_dirs=($(get_venv_dirs))
            for dir in "${venv_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    for venv in "$dir"/*; do
                        if [ -d "$venv" ] && { [ -f "$venv/pyvenv.cfg" ] || [ -d "$venv/bin" ] || [ -d "$venv/Scripts" ]; }; then
                            local venv_name=$(basename "$venv")
                            env_list+=("$venv_name")
                            env_count=$((env_count+1))
                            echo -e "${GREEN}$env_count)${NC} $venv_name"
                        fi
                    done
                fi
            done
            
            # 从conda获取环境
            if command -v conda &> /dev/null; then
                conda env list 2>/dev/null | grep -v "^#" | while read -r line; do
                    env_name=$(echo "$line" | awk '{print $1}')
                    if [ "$env_name" != "base" ]; then
                        env_list+=("$env_name")
                        env_count=$((env_count+1))
                        echo -e "${GREEN}$env_count)${NC} $env_name"
                    fi
                done
            fi
            
            if [ $env_count -eq 0 ]; then
                echo -e "${YELLOW}未找到任何虚拟环境${NC}"
                read -p "按回车键继续..."
                show_menu
            else
                echo
                read -p "请选择要删除的环境 [1-$env_count]: " env_choice
                
                if [[ $env_choice =~ ^[0-9]+$ ]] && [ $env_choice -ge 1 ] && [ $env_choice -le $env_count ]; then
                    local selected_env="${env_list[$env_choice-1]}"
                    delete_environment "$selected_env"
                    echo
                    read -p "按回车键继续..."
                else
                    echo -e "${RED}无效的选择${NC}"
                    sleep 1
                fi
                show_menu
            fi
            ;;
        0)
            echo -e "${GREEN}感谢使用！再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            sleep 1
            show_menu
            ;;
    esac
}

# 主函数
main() {
    # 检查是否为非交互式模式
    if has_flag "--non-interactive" "$@"; then
        NON_INTERACTIVE=true
    fi
    
    # 检查依赖
    check_dependencies
    
    # 解析命令行参数，过滤掉全局标志
    local args=("$@")
    local command=""
    local params=()
    local i=0
    
    # 提取命令和参数，过滤掉全局标志
    for arg in "${args[@]}"; do
        if [ $i -eq 0 ]; then
            command="$arg"
        elif [[ "$arg" != "--non-interactive" ]]; then
            params+=("$arg")
        fi
        i=$((i+1))
    done
    
    case "$command" in
        list)
            list_environments
            ;;
        info)
            show_environment_info "${params[0]}"
            ;;
        create)
            create_environment "${params[0]}" "${params[1]}" "${params[2]}"
            ;;
        delete)
            # 检查是否有--force标志
            if has_flag "--force" "${params[@]}"; then
                # 过滤掉--force标志
                local env_name=""
                for param in "${params[@]}"; do
                    if [ "$param" != "--force" ]; then
                        env_name="$param"
                        break
                    fi
                done
                delete_environment "$env_name" "--force"
            else
                delete_environment "${params[0]}"
            fi
            ;;
        menu)
            show_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            if [ -z "$command" ]; then
                # 如果没有提供命令，默认启动交互式菜单
                show_menu
            else
                echo -e "${RED}错误： 未知命令 '$command'${NC}"
                echo -e "运行 ${GREEN}./venv-manager.sh help${NC} 查看可用命令"
                exit 1
            fi
            ;;
    esac
}

# 执行主函数
main "$@"
