set nocompatible 
filetype off 
set rtp+=~/.vim/bundle/Vundle.vim 
call vundle#begin() 
Plugin 'gmarik/Vundle.vim' "required
Plugin 'tpope/vim-fugitive' "required 
Plugin 'tpope/vim-sensible'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'scrooloose/nerdcommenter'
Plugin 'Shougo/neocomplcache.vim'
Plugin 'nathanaelkane/vim-indent-guides'
call vundle#end()            
filetype plugin indent on " Put your non-Plugin stuff after this line
set tabstop=4
set shiftwidth=4
set expandtab
