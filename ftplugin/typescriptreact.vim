if !exists('*GotoModuleTs')
    runtime ftplugin/_ts_common.vim
endif

nmap <buffer> <leader>m :call GotoModuleTs()<CR>
