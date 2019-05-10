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
Plugin 'ctags.vim'
call vundle#end()            
filetype plugin indent on " Put your non-Plugin stuff after this line
"NERDTree ON 단축키를 "\nt"로 설정
map nt :NERDTreeToggle<CR>
let NERDTreeShowHidden=1
set tabstop=4
set shiftwidth=4
set expandtab
