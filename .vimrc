" Configiration file for gvim
" Written for Debian GNU/Linux by W.Akkerman <wakkerma@debian.org>
" Some modifications by J.H.M. Dassen <jdassen@wi.LeidenUniv.nl>
" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements

" map ctrl-n and ctrl-p to buffer next/prev
map <C-n> :bn<CR>
map <C-p> :bp<CR>
map <C-u> :redo<CR>

" If you have problems with your backspace/del key, uncomment the next 3 lines."
" set t_kb=^V 
set t_kD=^V
":fixdel

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements
set nocompatible	" Use Vim defaults (much better!)
"set backspace=2		" allow backspacing over everything in insert mode
set backspace=indent,eol,start	" same as above but better ?
" Now we set some defaults for the editor 
"set expandtab
set ts=4			" set tab stop width to 4
set sw=4			" set the shift width to 4 spaces
" 4 spaces will be treated like a tab (eg. when using backspace)
set sts=4			" set the soft tabstop to 4 spaces
"set smarttab
set expandtab
" don't expand tabs (replace the with spaces) in python mode
autocmd FileType python set tabstop=4|set shiftwidth=4|set noexpandtab

set nobackup       " no backup files
set nowritebackup  " only in case you don't want a backup file while editing
set noswapfile     " no swap files

" https://unix.stackexchange.com/a/140584
set mouse=r        " disable visual mode on mouse selection (mouse=a)

abbreviate #b /*********************************************************
abbreviate #e  *********************************************************/
set textwidth=0		" Don't wrap words by default
"set textwidth=78   " wrap words
"set foldmethod=indent
"set nobackup		" Don't keep a backup file
set viminfo='20,\"50	" read/write a .viminfo file, don't store more than
			" 50 lines of registers
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time

" Suffixes that get lower priority when doing tab completion for filenames.
" These are files we are not likely to want to edit or read.
set suffixes=.bak,~,.swp,.o,.info,.aux,.log,.dvi,.bbl,.blg,.brf,.cb,.ind,.idx,.ilg,.inx,.out,.toc

" We know xterm-debian is a color terminal
if &term =~ "xterm-debian" || &term =~ "xterm-xfree86"
  set t_Co=16
  set t_Sf=[3%dm
  set t_Sb=[4%dm
endif

" Vim5 comes with syntaxhighlighting. If you want to enable syntaxhightlighting
" by default uncomment the next three lines. 
if has("syntax")
  syntax on		" Default to no syntax highlightning 
endif

" Debian uses compressed helpfiles. We must inform vim that the main
" helpfiles is compressed. Other helpfiles are stated in the tags-file.
set helpfile=$VIMRUNTIME/doc/help.txt.gz

if has("autocmd")

" Set some sensible defaults for editing C-files
augroup cprog
  " Remove all cprog autocommands
  au!

  " When starting to edit a file:
  "   For *.c and *.h files set formatting of comments and set C-indenting on.
  "   For other files switch it off.
  "   Don't change the order, it's important that the line with * comes first.
  autocmd BufRead *       set formatoptions=tcql nocindent comments&
  autocmd BufRead *.c,*.h,*.cc,*.php,*.php3 set formatoptions=croql cindent comments=sr:/*,mb:*,el:*/,://
augroup END

" Also, support editing of gzip-compressed files. DO NOT REMOVE THIS!
" This is also used when loading the compressed helpfiles.
"augroup gzip
  " Remove all gzip autocommands
"  au!

  " Enable editing of gzipped files
  "	  read:	set binary mode before reading the file
  "		uncompress text in buffer after reading
  "	 write:	compress file after writing
  "	append:	uncompress file, append, compress file
"  autocmd BufReadPre,FileReadPre	*.gz set bin
"  autocmd BufReadPre,FileReadPre	*.gz let ch_save = &ch|set ch=2
"  autocmd BufReadPost,FileReadPost	*.gz '[,']!gunzip
"  autocmd BufReadPost,FileReadPost	*.gz set nobin
"  autocmd BufReadPost,FileReadPost	*.gz let &ch = ch_save|unlet ch_save
"  autocmd BufReadPost,FileReadPost	*.gz execute ":doautocmd BufReadPost " . expand("%:r")

"  autocmd BufWritePost,FileWritePost	*.gz !mv <afile> <afile>:r
"  autocmd BufWritePost,FileWritePost	*.gz !gzip <afile>:r

"  autocmd FileAppendPre			*.gz !gunzip <afile>
"  autocmd FileAppendPre			*.gz !mv <afile>:r <afile>
"  autocmd FileAppendPost		*.gz !mv <afile> <afile>:r
"  autocmd FileAppendPost		*.gz !gzip <afile>:r
"augroup END

"augroup bzip2
  " Remove all bzip2 autocommands
"  au!

  " Enable editing of bzipped files
  "       read: set binary mode before reading the file
  "             uncompress text in buffer after reading
  "      write: compress file after writing
  "     append: uncompress file, append, compress file
"  autocmd BufReadPre,FileReadPre        *.bz2 set bin
"  autocmd BufReadPre,FileReadPre        *.bz2 let ch_save = &ch|set ch=2
"  autocmd BufReadPost,FileReadPost      *.bz2 |'[,']!bunzip2
"  autocmd BufReadPost,FileReadPost      *.bz2 let &ch = ch_save|unlet ch_save
"  autocmd BufReadPost,FileReadPost      *.bz2 execute ":doautocmd BufReadPost " . expand("%:r")

"  autocmd BufWritePost,FileWritePost    *.bz2 !mv <afile> <afile>:r
"  autocmd BufWritePost,FileWritePost    *.bz2 !bzip2 <afile>:r

"  autocmd FileAppendPre                 *.bz2 !bunzip2 <afile>
"  autocmd FileAppendPre                 *.bz2 !mv <afile>:r <afile>
"  autocmd FileAppendPost                *.bz2 !mv <afile> <afile>:r
"  autocmd FileAppendPost                *.bz2 !bzip2 -9 --repetitive-best <afile>:r
"augroup END

endif " has ("autocmd")

" Some Debian-specific things
augroup filetype
  au BufRead reportbug.*		set ft=mail
augroup END

" The following are commented out as they cause vim to behave a lot
" different from regular vi. They are highly recommended though.
set makeprg=gmake
set showcmd		" Show (partial) command in status line.
set showmatch		" Show matching brackets.
set ignorecase		" Do case insensitive matching
set incsearch		" Incremental search
set autowrite		" Automatically save before commands like :next and :make

" XML formatter
function! DoFormatXML() range
    " Save the file type
    let l:origft = &ft

    " Clean the file type
    set ft=

    " Add fake initial tag (so we can process multiple top-level elements)
    exe ":let l:beforeFirstLine=" . a:firstline . "-1"
    if l:beforeFirstLine < 0
        let l:beforeFirstLine=0
    endif
    exe a:lastline . "put ='</PrettyXML>'"
    exe l:beforeFirstLine . "put ='<PrettyXML>'"
    exe ":let l:newLastLine=" . a:lastline . "+2"
    if l:newLastLine > line('$')
        let l:newLastLine=line('$')
    endif

    " Remove XML header
    exe ":" . a:firstline . "," . a:lastline . "s/<\?xml\\_.*\?>\\_s*//e"

    " Recalculate last line of the edited code
    let l:newLastLine=search('</PrettyXML>')

    " Execute external formatter
    exe ":silent " . a:firstline . "," . l:newLastLine . "!xmllint --noblanks --format --recover -"

    " Recalculate first and last lines of the edited code
    let l:newFirstLine=search('<PrettyXML>')
    let l:newLastLine=search('</PrettyXML>')
    
    " Get inner range
    let l:innerFirstLine=l:newFirstLine+1
    let l:innerLastLine=l:newLastLine-1

    " Remove extra unnecessary indentation
    exe ":silent " . l:innerFirstLine . "," . l:innerLastLine "s/^  //e"

    " Remove fake tag
    exe l:newLastLine . "d"
    exe l:newFirstLine . "d"

    " Put the cursor at the first line of the edited code
    exe ":" . l:newFirstLine

    " Restore the file type
    exe "set ft=" . l:origft
endfunction
command! -range=% FormatXML <line1>,<line2>call DoFormatXML()

nmap <silent> <leader>x :%FormatXML<CR>
vmap <silent> <leader>x :FormatXML<CR>

function! DoPrettyXML()
  " save the filetype so we can restore it later
  let l:origft = &ft
  set ft=
  " delete the xml header if it exists. This will
  " permit us to surround the document with fake tags
  " without creating invalid xml.
  1s/<?xml .*?>//e
  " insert fake tags around the entire document.
  " This will permit us to pretty-format excerpts of
  " XML that may contain multiple top-level elements.
  0put ='<PrettyXML>'
  $put ='</PrettyXML>'
  silent %!xmllint --format -
  " xmllint will insert an <?xml?> header. it's easy enough to delete
  " if you don't want it.
  " delete the fake tags
  2d
  $d
  " restore the 'normal' indentation, which is one extra level
  " too deep due to the extra tags we wrapped around the document.
  silent %<
  " back to home
  1
  " restore the filetype
  exe "set ft=" . l:origft
endfunction
command! PrettyXML call DoPrettyXML()
