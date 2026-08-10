#!/bin/bash

######################################################################
# Script Name  : setting_mac.sh                                      #
# Description  : macOS 사용자 환경 구성 스크립트                     #
# Author       : hipbone                                             #
# Last Update  : 2026-08-10                                          #
######################################################################
#
# 주의: 현재 Ubuntu/WSL 기준으로만 검증되어 있습니다.
#       macOS 장비를 다시 쓰게 되면 이 스크립트로 검증 후 setEnv.sh 로 통합할 것.
#       사전에 Homebrew가 설치되어 있어야 합니다.

### Variables ###
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

### Functions ###
## zsh install and update
zsh_update() {
    if [ $(which brew) ];then
        test $(which zsh) || brew install zsh
    else
        echo "brew를 설치하세요."
        exit 1
    fi
}

install_oh_my_zsh() {
    ## install requirements packages
    for pkg in wget curl git
    do
        test $(which ${pkg}) || brew install ${pkg}
    done

    ## install oh-my-zsh
    if [ ! -d "${HOME}/.oh-my-zsh" ];then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "oh-my-zsh은 이미 설치되었습니다."
    fi
}

install_zsh_theme() {
    ## powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ];then
        git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
    fi
}

install_zsh_plugin() {
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ];then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
    fi
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ];then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
    fi
    test $(which bat) || brew install bat
}

# 기존 파일을 백업 (심볼릭 링크는 그냥 덮어씀)
backup_if_real_file() {
    local target="$1"
    if [ -e "${target}" ] && [ ! -L "${target}" ]; then
        mv "${target}" "${target}.bak"
        echo "  기존 파일을 백업했습니다: ${target}.bak"
    fi
}

## 설정 파일 심볼릭 링크
## Ubuntu(setEnv.sh -e default + dotfiles)와 동일한 대상을 연결한다.
set_link() {
    backup_if_real_file "${HOME}/.zshrc"
    ln -fs "${repo_dir}/zshrc_mac"       "${HOME}/.zshrc"
    ln -fsn "${repo_dir}/alias"          "${HOME}/alias"
    ln -fsn "${repo_dir}/functions"      "${HOME}/functions"

    backup_if_real_file "${HOME}/.vimrc"
    ln -fs "${repo_dir}/config/vimrc"    "${HOME}/.vimrc"

    backup_if_real_file "${HOME}/.tmux.conf"
    ln -fs "${repo_dir}/config/tmux.conf" "${HOME}/.tmux.conf"

    backup_if_real_file "${HOME}/.p10k.zsh"
    ln -fs "${repo_dir}/config/p10k.zsh" "${HOME}/.p10k.zsh"

    echo "설정 파일을 연결했습니다."
}

### main
zsh_update
install_oh_my_zsh
install_zsh_theme
install_zsh_plugin
set_link
source ${HOME}/.zshrc
