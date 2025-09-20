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
        let l:files = split(glob(a:path . '/index*'), "\n")

        for l:file in l:files
            if filereadable(l:file)
                call add(l:results, l:file)
            endif
        endfor

        if !empty(l:results)
            return l:results
        endif

        return [a:path . '/']
    endif

    " Return an empty list if no matches are found in any section
    return []
endfunction

function! s:ResolvePath(module)
    let l:current_file_dir = fnamemodify(expand('%:p'), ':h')

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
        let l:candidate = l:current_dir . '/tsconfig.json'
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
        let l:base_url_match = matchlist(l:content, '\v"baseUrl"\s*:\s*"(.{-})"')
        if !empty(l:base_url_match)
            let l:base_url = resolve(fnamemodify(l:ts_config_path, ':h') . '/' . l:base_url_match[1])
            let l:paths_match = matchlist(l:content, '\v"paths"\s*:\s*(\{.{-}\})')
            if !empty(l:paths_match)
                let l:paths_map = json_decode(substitute(l:paths_match[1], '\*', '', 'g'))

                for [l:alias, l:alias_path] in items(l:paths_map)
                    if a:module =~ '^' . l:alias

                        " todo, only checking the first item
                        let l:resolved_alias = substitute(l:alias_path[0], '\*$', '', '')
                        let l:resolved_path = resolve(l:base_url . '/' . l:resolved_alias . substitute(a:module, '^' . l:alias, '', ''))
                        if !empty(l:resolved_path)
                            if l:resolved_path =~ '^' . getcwd()
                                return s:ResolveFile(fnamemodify(l:resolved_path, ':.'))
                            else
                                return s:ResolveFile(l:resolved_path)
                            endif
                        endif
                    endif
                endfor
            endif
        endif
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

function! GotoModuleTs()
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
        let l:resolved_paths = s:ResolveFile(l:found_module)

        echom 'resolved_paths: ' . string(l:resolved_paths)

        if !empty(l:resolved_paths)
            if len(l:resolved_paths) == 1
                execute 'silent vertical split ' . l:resolved_paths[0]
            else
                let l:choice = inputlist('Choose a file to open:', l:resolved_paths)
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
