if !exists('*GotoModuleTs')
    runtime ftplugin/_ts_common.vim
endif

nmap <buffer>         <leader>m :call GotoModuleTs()\|:set hlsearch<CR>
nmap <buffer> <leader><leader>m :call GotoModuleTs(1)\|:set hlsearch<CR>
vmap <buffer>         <leader>m :call GotoModuleTs(0,1)\|:set hlsearch<CR>
vmap <buffer> <leader><leader>m :call GotoModuleTs(1,1)\|:set hlsearch<CR>
