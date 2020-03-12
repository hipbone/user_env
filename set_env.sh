#!/bin/bash

# Variables
OS=`uname -s`

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

get_os

case ${OS} in 
  centos)
    # zsh  && plugins install
    [ ! -f $(which zsh) ] && yum install -y zsh
    yum install -y autojump-zsh
    # fzf install for zsh-interactive-cd
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install
    ;;
  Darwin)
    # plugin install
    brew install -y autojump
    ln -fs ~/User_env/zshrc_mac ~/.zshrc
    ln -fs ~/User_env/bash_profile_mac ~/.bash_profile
    ln -fs ~/user_env/.vimrc ~/.vimrc
    ln -fs ~/user_env/.vim ~/.vim
    ;;
esac

#source ~/.zshrc
#source ~/.bash_profile
