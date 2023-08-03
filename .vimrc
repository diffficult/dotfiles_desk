filetype on
filetype plugin indent on
filetype plugin on
syntax on

let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'default'
let g:airline_theme = 'embark'

set completeopt-=preview

set laststatus=2
set noshowmode

set showcmd
set ignorecase
set smartcase
set expandtab
set smarttab
set hlsearch
set number
set noswapfile
set cursorline
set autoindent
set shiftwidth=4
set softtabstop=4
set scrolloff=8
set sidescrolloff=10

set timeoutlen=1000
set ttimeoutlen=0

set clipboard=unnamed
set clipboard^=unnamedplus

:noremap / :set hlsearch<CR>/

:noremap <F2> :set paste! nopaste?<CR>

:noremap <F3> :set nonumber! nonumber?<CR>

:noremap <F4> :set hlsearch! hlsearch?<CR>

set background=dark

function TrimWhitespace()
  %s/\s*$//
  ''
:endfunction
command! Trim call TrimWhitespace()
 map <F10> :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
 \ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
 \ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>

set hidden
let mapleader=","
nmap <leader>n :enew<cr>
nmap <leader><leader> :bnext<CR>
nmap <leader>. :bprevious<CR>
nmap <leader>l :ls<CR>
