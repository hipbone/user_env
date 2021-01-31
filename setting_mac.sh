#!/bin/bash

### Variables ###
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

### Functions ###
## zsh install and update
function zsh_update() {
    if [ $(which brew) ];then
        brew install zsh
    else
        echo "brew를 설치하세요."
        exit 1
    fi
}

function install_oh-my-zsh() {
    ## install requirements packages
    brew install wget curl git

    ## install oh-my-zsh
    if [ ! -d "${HOME}/.oh-my-zsh" ];then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "oh-my-zsh은 이미 설치되었습니다."
    fi
}

function install_zsh_theme() {
    ## powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ];then
        git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
    fi
    cp -f zshrc_mac ${HOME}/.zshrc
}

### main
## zsh install and update
# zsh_update
## install oh-my-zsh 
# install_oh-my-zsh
install_zsh_theme
