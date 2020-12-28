#!/usr/bin/env bash

#description server packaging for 'MRO'

clear
echo

# 代码拉去路径
clone_path="/home/html/temp"

# 静态文件位置
web_path="/app/scs/web"

# 默认构建环境
evn="prod"

# svn代码仓库地址
svn_address="https://192.168.158.242/svn/web2/code/SupplyChain"

# git代码仓库地址 wuxiang 账号有所有权限
git_address="http://wuxiang:wx360124@192.168.173.100:90/web"

# 设置展示颜色
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
# 定义信息类型
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

# 拉取代码
#params ${1}：模块 wms admin agent data hscg ${2}：路径 ${3}：环境 master test
clone_code_model() {
    # 进入代码父目录
    cd ${clone_path}
    if [[ ${1} == "hscg" ]]; then
        echo -e "${Tip}--[路径] git clone ${3} ${git_address}/${2} ${clone_path}/${1}"
        clone_logs=$(git clone -b ${3} ${git_address}/${2} ${clone_path}/${1} 2>&1)
        # 第一行信息中存在 already exists 说明已经拉取或者是空路径
        if [[ "$clone_logs | tail 1" == *exists* ]]; then
            echo -e "${Tip} 代码已经拉取过了直接pull....."
        elif [[ "$clone_logs | tail 1" == *fatal* ]]; then
            echo -e "${Error} 代码拉取失败....."
            echo "失败日志如下："
            echo ${clone_logs} && exit 1
        fi
        sleep 1
        cd ${clone_path}/${1}
        sleep 1
        # git 需要pull下不然会炸
        pull_logs=$(git pull 2>&1)
        if [[ "$pull_logs | tail 1" == *fatal* ]]; then
            echo -e "${Error} 代码拉取失败....."
            echo "失败日志如下："
            echo ${pull_logs} && exit 1
        fi
    else
        echo -e "${Tip}--[路径] svn co ${svn_address}/${2} ${clone_path}/${1}"
        svn_logs=$(svn co ${svn_address}/${2} ${clone_path}/${1} 2>&1)
        # svn错误码都是e175xxx
        if [[ "$svn_logs | tail 1" == *E175* ]]; then
            echo -e "${Error} 代码拉取失败....."
            echo "失败日志如下："
            echo ${svn_logs} && exit 1
        fi
    fi
    echo -e "${Info} 成功拉取 ${1} 代码....."
}

# 拉取代码前判断
#params ${1}：模块 wms admin agent data hscg ${2}：环境 master test
clone_code() {
    echo " "
    echo -e "${Tip} 开始拉取 ${1} 代码....."
    echo " "
    # svn 预发
    if [[ ${1} == "wms" && ${2} == "master" ]]; then
        model="wms"
    elif [[ ${1} == "admin" && ${2} == "master" ]]; then
        model="mro-Admin"
    elif [[ ${1} == "agent" && ${2} == "master" ]]; then
        model="mro-admin-dls"
    elif [[ ${1} == "data" && ${2} == "master" ]]; then
        model="mro-full-screen"
    # svn 测试
    elif [[ ${1} == "wms" && ${2} == "test" ]]; then
        model="branches/wms-admin_test"
    elif [[ ${1} == "admin" && ${2} == "test" ]]; then
        model="branches/mro-admin_test"
    elif [[ ${1} == "agent" && ${2} == "test" ]]; then
        model="branches/mro-admin-dls_test"
    elif [[ ${1} == "data" && ${2} == "test" ]]; then
        model="branches/mro-full-screen_test"
    # git 项目
    elif [[ ${1} == "hscg" && (${2} == "master" || ${2} == "test") ]]; then
        model="mro-bidding-admin.git"
    else
        echo -e "${Tip} ${1} 或 ${2} 项目名或分支错了，mmp菜狗！" && exit 1
    fi
    # 执行拉去代码
    clone_code_model ${1} ${model} ${2}
}

# 构建代码
#params ${1}：模块
build_code() {
    echo -e "${Tip} 开始构建 ${1} 模块....."

    cd ${clone_path}/${1}

    rm -rf ${clone_path}/${1}/dist

    # yarn install
    install_logs=$(yarn install 2>&1)
    if [[ "$install_logs | tail -1" == *Done* ]]; then
        echo -e "${Info} yarn install 成功....."
    else
        echo -e "${Error} yarn install 失败....."
        echo "失败日志如下："
        echo ${install_logs} && exit 1
    fi

    # yarn run build
    echo -e "${Info} yarn run build 打包中....."
    build_logs=$(yarn run build:${evn} --report 2>&1)
    if [[ "$build_logs | tail -1" == *Done* ]]; then
        echo -e "${Info} 构建 ${1} 模块 成功....."
    else
        echo -e "${Error} 构建 ${1} 模块 失败....."
        echo "失败日志如下："
        echo ${build_logs} && exit 1
    fi

}

# 备份旧版本
backups_old_code() {
    echo " "
}

# 复制代码文件
#params ${1}：模块 ${2}：model
copy_code_model() {
    echo -e "${Tip} 开始复制 ${1} 模块静态文件....."
    # 先创建文件夹，如果不存在的话
    mkdir -p ${web_path}/${2}
    # 删除原文件内容
    rm -rf ${web_path}/${2}/*
    echo -e "${Tip} 删除 ${web_path}/${2}/ 模块静态文件成功....."
    # 移动最新前端文件到web目录
    cp -a ${clone_path}/${1}/dist/* ${web_path}/${2}/
    echo -e "${Info} 成功复制 ${clone_path}/${1}/dist/ 模块静态文件至 ${web_path}/${2}/ 中....."
}

# 复制代码
copy_code() {
    if [[ ${1} == "wms" ]]; then
        copy_code_model ${1} "${1}/dist"
    elif [[ ${1} == "admin" ]]; then
        copy_code_model ${1} ${1}
    elif [[ ${1} == "agent" ]]; then
        copy_code_model ${1} ${1}
    elif [[ ${1} == "data" ]]; then
        copy_code_model ${1} "${1}/dist"
    elif [[ ${1} == "hscg" ]]; then
        copy_code_model ${1} ${1}
    fi
}

# 启动
initBuild() {
    echo -e "${Info} 开始打包：${Red_font_prefix}${1}....."
    # 拉取代码
    clone_code ${1} ${2}
    # 构建编译代码
    build_code ${1}
    # 复制代码到 web 目录下
    copy_code ${1}
}

echo
echo "*******编译开始********"

#description enter
#params ${1} = 项目名 wms admin agent data hscg ${2} = 分支类型 master or test

initBuild $*
echo
echo "*******编译结束********"
