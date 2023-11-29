#!/bin/bash

## Variables
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
ALIAS_DIR="${PWD}/alias"

function get_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=${ID}
    VER=${VERSION_ID}
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi
}

function set_zsh_for_linux() {
  echo ''  
}

# OS, VER 정보 가져오기
get_os

function requirement_package() {
  $PKG_MANAGER install -y wget curl git zsh bat
}



case ${OS} in 
  centos)
    PKG_MANAGER="sudo yum"
    ZSH_FILE="zshrc_centos"
    # zsh  && plugins install
    [ ! $(which zsh) ] && yum install -y zshset_env.sh
    yum install -y autojump-zsh
    # fzf install for zsh-interactive-cd
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install

    # default .zshrc 복사
    cp ~/user_env/zshrc_centos ~/.zshrc
    ;;
  Darwin)
    PKG_MANAGER="brew"
    ZSH_FILE="zshrc_mac"
    # plugin install
    brew install -y autojump
    ln -fs ~/User_env/zshrc_mac ~/.zshrc
    ln -fs ~/User_env/bash_profile_mac ~/.bash_profile
    ln -fs ~/user_env/.vimrc ~/.vimrc
    ln -fs ~/user_env/.vim ~/.vim
    ;;
  ubuntu)
    PKG_MANAGER="sudo apt"
    ZSH_FILE="${PWD}/zshrc_ubuntu"
    ;;
esac

# 필수 패키지 설치
requirement_package "$PKG_MANAGER"

## install oh-my-zsh
if [ ! -d "${HOME}/.oh-my-zsh" ];then
    Yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "oh-my-zsh은 이미 설치되었습니다."
fi

## powerlevel10k theme 설치
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ];then
    git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
fi

# zsh 플러그인 설치
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ];then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ];then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh symlink
ln -fs "${ZSH_FILE}" "${HOME}"/.zshrc
ln -fs "${ALIAS_DIR}" "${HOME}"/alias"

source "${HOME}"/.zshrc
