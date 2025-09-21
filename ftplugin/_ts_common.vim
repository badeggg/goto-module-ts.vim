" Helper function to resolve files
function! s:ResolveFile(path)
    let l:results = []

    " Section 1: Check for specific file extensions
    if fnamemodify(a:path, ':e') =~? '^\(css\|ts\|tsx\|js\|jsx\)$'
        if filereadable(a:path)
            return [a:path]
        endif
    endif

    " Section 2: Check for a file with a set of extensions
    let l:extensions = ['.d.ts', '.js', '.jsx', '.ts', '.tsx']
    for l:ext in l:extensions
        if filereadable(a:path . l:ext)
            call add(l:results, a:path . l:ext)
        endif
    endfor
    if !empty(l:results)
        return l:results
    endif

    " Section 3: Check for any 'index' files in a directory
    if isdirectory(a:path)
        let l:files = split(glob(resolve(a:path . '/index*')), "\n")

        for l:file in l:files
            if filereadable(l:file)
                call add(l:results, l:file)
            endif
        endfor

        if !empty(l:results)
            return l:results
        endif

        return [resolve(a:path . '/')]
    endif

    " Return an empty list if no matches are found in any section
    return []
endfunction

function! s:ResolvePath(module, ...)
    let l:current_file_dir = fnamemodify(expand('%:p'), ':h')
    let l:custom_tsconfig = a:0 >= 1 ? a:1 : 0

    " Relative module
    if a:module =~ '^\.'
        let l:path = fnamemodify(resolve(l:current_file_dir . '/' . a:module), ':p')
        if l:path =~ '^' . getcwd()
            return s:ResolveFile(fnamemodify(l:path, ':.'))
        else
            return s:ResolveFile(l:path)
        endif
    endif

    " Find and parse tsconfig.json for aliases
    let l:current_dir = l:current_file_dir
    let l:ts_config_path = ''
    while !empty(l:current_dir)
        let l:candidate = l:current_dir . (l:custom_tsconfig ? '/custom_tsconfig.json' : '/tsconfig.json')
        if filereadable(l:candidate)
            let l:ts_config_path = l:candidate
            break
        endif
        let l:parent_dir = fnamemodify(l:current_dir, ':h')
        if l:parent_dir ==# l:current_dir
            break
        endif
        let l:current_dir = l:parent_dir
    endwhile

    if !empty(l:ts_config_path)
        let l:content = join(readfile(l:ts_config_path), '')
        let l:json = json_decode(l:content)
        let l:base_url = resolve(fnamemodify(l:ts_config_path, ':h') . '/' . l:json['compilerOptions']['baseUrl'])
        let l:paths_map = l:json['compilerOptions']['paths']

        for [l:alias, l:alias_path] in items(l:paths_map)
            if a:module =~ '^' . l:alias

                for l:path_item in l:alias_path
                    let l:resolved_alias = substitute(l:path_item, '\*$', '', '')
                    let l:resolved_path = resolve(l:base_url . '/' . l:resolved_alias . substitute(a:module, '^' . l:alias, '', ''))
                    let l:resolved_path = fnamemodify(l:resolved_path, ':p')
                    
                    if !empty(l:resolved_path)
                        if l:resolved_path =~ '^' . getcwd()
                            return s:ResolveFile(fnamemodify(l:resolved_path, ':.'))
                        else
                            return s:ResolveFile(l:resolved_path)
                        endif
                    endif
                endfor
            endif
        endfor
    endif

    " node_modules
    let l:current_dir = l:current_file_dir
    while !empty(l:current_dir)
        let l:node_modules_dir = l:current_dir . '/node_modules'
        if isdirectory(l:node_modules_dir)
            let l:resolved_path = l:node_modules_dir . '/' . a:module
            if !empty(l:resolved_path)
                return s:ResolveFile(l:resolved_path)
            endif
        endif
        let l:parent_dir = fnamemodify(l:current_dir, ':h')
        if l:parent_dir ==# l:current_dir
            break
        endif
        let l:current_dir = l:parent_dir
    endwhile

    return []
endfunction

function! GotoModuleTs(...)
    let l:custom_tsconfig = a:0 >= 1 ? a:1 : 0

    let l:found_module = ''

    " todo, not respecting import and 'xxx' are separated in two lines
    " check: import 'xxx'
    let l:match_import = matchlist(getline('.'), '\vimport\s+[''"](.{-})[''"]')
    if !empty(l:match_import)
        let l:found_module = l:match_import[1]
    endif

    " todo, not respecting from and 'xxx' are separated in two lines
    " check: from 'xxx'
    if empty(l:found_module)
        for l:i in range(line('.'), line('$'))
            let l:line_content = getline(l:i)
            let l:match_from = matchlist(l:line_content, '\vfrom\s+[''"](.{-})[''"]')

            if !empty(l:match_from)
                let l:found_module = l:match_from[1]
                break
            endif
        endfor
    endif

    if !empty(l:found_module)
        let l:resolved_paths = s:ResolvePath(l:found_module, l:custom_tsconfig)

        echom 'resolved_paths: ' . string(l:resolved_paths)

        if !empty(l:resolved_paths)
            if len(l:resolved_paths) == 1
                execute 'silent vertical split ' . l:resolved_paths[0]
            else
                let l:max_path_len = 0
                for l:path in l:resolved_paths
                    if len(l:path) > l:max_path_len
                        let l:max_path_len = len(l:path)
                    endif
                endfor

                let l:numbered_paths = []
                for l:idx in range(len(l:resolved_paths))
                    let l:format_string = '%-' . l:max_path_len . 's %d'
                    let l:numbered_paths += [printf(l:format_string, l:resolved_paths[l:idx], l:idx + 1)]
                endfor

                let l:options = ['Choose a file to open:'] + l:numbered_paths
                let l:choice = inputlist(l:options)
                if l:choice > 0
                    execute 'silent vertical split ' . l:resolved_paths[l:choice - 1]
                endif
            endif
        else
            echom "Error: Could not resolve path for module: " . l:found_module
        endif
    else
        echom "No import or from statement found from the current line onwards."
    endif
endfunction
