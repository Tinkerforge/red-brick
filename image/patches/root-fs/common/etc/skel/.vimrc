" common

"colorscheme desert
set background=light
"vim? vi? VIM!
set nocompatible
"there exist no modem-connection
set ttyfast
"linux terminal to interpret function keys currectly
"set term=linux
"no bells; if you want visual message type => set visualbell
set visualbell t_vb=
"show matching brackets
set showmatch
"...but shown only 4 tenth of a second
set matchtime=4
"always show statusline
set laststatus=2
"allow backspace everything
set backspace=indent,eol,start
"do you like c indent?
set cindent
"set tabstop to 8 characters
set tabstop=4
"set shiftwidth to 8 spaces
set sw=4
"always set auto-indenting on
set ai
"always show ruler
set ruler
"write a viminfo file
set viminfo='20,\"50
"show parial pattern matches in real time
set incsearch
" I like highlighted search pattern
set hlsearch
"living on the edge, no backup
set nobackup
"use a scrollable menu for filename completions
set wildmenu
"ignore class and object files
set wildignore=*.class,*.o
"display folders ( sympathie with the devil )
set foldcolumn=0
"of course
syntax on
" unset modelines
set nomodeline
"I need more information
set statusline=%<%f%=\ [%1*%M%*%n%R%H%Y]\ \ %-25(%3l,%c%03V\ \ %P\ (%L)%)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TEST-SUITE

"report after N lines changed; default is two
set report=0
"maximum mumber of undos
set undolevels=200

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TEXT FORMATING

augroup syntax
au! BufNewFile,BufReadPost *.smv
au  BufNewFile,BufReadPost *.smv  so /usr/share/vim/vim71/syntax/smv.vim
augroup END

if has("autocmd")

  filetype on
    augroup filetype
    autocmd BufNewFile,BufRead *.txt set filetype=human
  augroup END

  "vim jumps always to the last edited line, if possible
  "autocmd BufRead *,.* :normal '"
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  "in human-language files, automatically format everything at 72 chars:
  autocmd FileType mail,human set formatoptions+=t textwidth=72 nocindent

  "LaTeX to the fullest! ...dislike overlong lines:
  autocmd FileType tex set formatoptions+=t textwidth=80 nocindent
  autocmd FileType tex set makeprg=latex\ %

  "for C-like programming, have automatic indentation:
  autocmd FileType slang set cindent tabstop=4 shiftwidth=4

  "Java
  autocmd FileType java set tabstop=4 shiftwidth=4
  autocmd FileType java set makeprg="ant compile\ %"
  autocmd FileType java set errorformat=\"%f\"\\\,\ line\ %l.%c:%m\,\ %f:%l:%m

  "for actual C (not C++) programming where comments have explicit end
  "characters, if starting a new line in the middle of a comment automatically
  "insert the comment leader characters:
  autocmd FileType c set formatoptions+=ro tabstop=4 shiftwidth=4
  
  autocmd FileType python set expandtab noai formatoptions+=ro tabstop=4 shiftwidth=4

  "for Perl programming, have things in braces indenting themselves:
  autocmd FileType perl set smartindent tabstop=3 shiftwidth=3

  "for CSS, also have things in braces indented:
  autocmd FileType css set smartindent

  "for HTML, generally format text, but if a long line has been created leave it
  "alone when editing:
  autocmd FileType html set expandtab formatoptions+=tl
  autocmd FileType javascript set expandtab formatoptions+=tl

  "for both CSS and HTML, use genuine tab characters for indentation, to make
  "files a few bytes smaller:
  autocmd FileType html,css,javascript set tabstop=2

  "in makefiles, don't expand tabs to spaces, since actual tab characters are
  "needed, and have indentation at 8 chars to be sure that all indents are tabs
  "(despite the mappings later):
          autocmd FileType make     set noexpandtab shiftwidth=8
          autocmd FileType automake set noexpandtab shiftwidth=8

endif " has("autocmd")


"java types, ...the solaris BG looks incredible yellow!
"highlight our functions
let java_highlight_functions=1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MAPPINGS

"Function Key's Sector
"F2 -> F4  == misc
"search the current word under cursor in all files in working directory
map <F2> vawy:! grep -n -H <C-R>" .* *<CR>
map <F3> :Sexplore<CR>

"buffer next/previous
map <F5> :bp<CR>
map <F6> :bN<CR>

"F9 -> F10 == spell checking with aspell
map <F9>  :w!<CR>:!aspell --lang=en -c %<CR>:e! %<CR>
map <F10> :w!<CR>:!aspell --lang=de -c %<CR>:e! %<CR>

"F11 -> F12 == resize window
map <F11>   <ESC>:TlistToggle <CR>
map <F12>   <ESC>:resize +5 <CR>

"Misc Keys

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ABBREVIATIATIONS (very necessary ;-)

iab _TIME        <C-R>=strftime("%X")<CR>
iab _DATE        <C-R>=strftime("%a %b %d %T %Z %Y")<CR>
iab _EPOCH       <C-R>=strftime("%s")<CR> 

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ENCODINGS

if v:lang =~ "^ko"
  set fileencodings=euc-kr
  set guifontset=-*-*-medium-r-normal--16-*-*-*-*-*-*-*
elseif v:lang =~ "^ja_JP"
  set fileencodings=euc-jp
  set guifontset=-misc-fixed-medium-r-normal--14-*-*-*-*-*-*-*
elseif v:lang =~ "^zh_TW"
  set fileencodings=big5
  set guifontset=-sony-fixed-medium-r-normal--16-150-75-75-c-80-iso8859-1,-taipei-fixed-medium-r-normal--16-150-75-75-c-160-big5-0
elseif v:lang =~ "^zh_CN"
  set fileencodings=gb2312
  set guifontset=*-r-*
endif
if v:lang =~ "utf8$" || v:lang =~ "UTF-8$"
  set fileencodings=utf-8,latin1
endif

"autocmd Filetype cpp,c,java,cs set omnifunc=cppcomplete#Complete 
autocmd FileType python set omnifunc=pythoncomplete#Complete
autocmd FileType javascript set omnifunc=javascriptcomplete#CompleteJS
autocmd FileType html set omnifunc=htmlcomplete#CompleteTags
autocmd FileType css set omnifunc=csscomplete#CompleteCSS
autocmd FileType xml set omnifunc=xmlcomplete#CompleteTags
autocmd FileType php set omnifunc=phpcomplete#CompletePHP
autocmd FileType c set omnifunc=ccomplete#Complete
autocmd FileType java set omnifunc=javacomplete#Complete

autocmd Filetype html setlocal ts=2 sts=2 sw=2
autocmd Filetype javascript setlocal ts=2 sts=2 sw=2

set tags+=~/.vim/systags
