#!/bin/bash

## Vundle install

git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
cp vimrc.default ~/.vimrc

## Python setting
## 특정 플러그인의 경우 pip로 모듈 설치가 필요함- virtualenv 환경에서 할것
# pip install autopep8 - Syntastic plugin

## 필요한 파일만 따로 보관중 - 다음 버전 release 될경우 다시 clone 필요
# git clone https://github.com/tell-k/vim-autopep8.git ~/.vim/bundle/

cp -r plugin ~/.vim
cp -r ftplugin ~/.vim
