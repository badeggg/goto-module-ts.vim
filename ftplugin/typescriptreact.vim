if !exists('*GotoModuleTs')
    runtime ftplugin/_ts_common.vim
endif

nmap <buffer> <leader>m :call GotoModuleTs({'use_custom_tsconfig': 0, 'selecting_module_str': 0})\|:set hlsearch<CR>
nmap <buffer> <leader>M :call GotoModuleTs({'use_custom_tsconfig': 1, 'selecting_module_str': 0})\|:set hlsearch<CR>
vmap <buffer> <leader>m :call GotoModuleTs({'use_custom_tsconfig': 0, 'selecting_module_str': 1})\|:set hlsearch<CR>
vmap <buffer> <leader>M :call GotoModuleTs({'use_custom_tsconfig': 1, 'selecting_module_str': 1})\|:set hlsearch<CR>
