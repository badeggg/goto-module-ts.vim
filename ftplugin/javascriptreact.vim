if !exists('*GotoModuleTs')
    runtime ftplugin/_ts_common.vim
endif

nmap <buffer>         <leader>m :call GotoModuleTs()\|:set hlsearch<CR>
" use custom_tsconfig.json
nmap <buffer> <leader><leader>m :call GotoModuleTs(1)\|:set hlsearch<CR>
