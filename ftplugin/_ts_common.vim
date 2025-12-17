" We solve 99% of the problem blazing fast, the 1% rare cases will introduce
" significant logic complexity if we solve them too, they deserve an inconvenience
" when encounter.



let s:CUSTOM_TSCONFIG_FILE_NAME = "custom_tsconfig.json"

" Helper function to resolve files
function! s:ResolveFile(path)
    let l:results = []

    " Section 1: Respect specified extension
    if !empty(fnamemodify(a:path, ':e'))
        if filereadable(a:path)
            return [a:path]
        endif
    endif

    " Section 2: Check for a file with a set of extensions
    let l:extensions = ['.d.ts', '.js', '.jsx', '.ts', '.tsx', '.json']
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

function! s:ResolvePath(module, use_custom_tsconfig)
    let l:current_file_dir = fnamemodify(expand('%:p'), ':h')

    " Relative module
    let l:path = fnamemodify(resolve(l:current_file_dir . '/' . a:module), ':p')
    let l:resolved = s:ResolveFile(fnamemodify(l:path, ':.'))
    if !empty(l:resolved)
        return l:resolved
    endif

    " Find and parse tsconfig.json for aliases
    let l:current_dir = l:current_file_dir
    let l:ts_config_path = ''
    while !empty(l:current_dir)
        let l:candidate = l:current_dir . (a:use_custom_tsconfig ? '/' . s:CUSTOM_TSCONFIG_FILE_NAME : '/tsconfig.json')
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
        let l:base_url = resolve(
            \ fnamemodify(l:ts_config_path, ':h') .
            \ '/' .
            \ get(l:json.compilerOptions, 'baseUrl', './')
            \)
        let l:paths_map = l:json.compilerOptions.paths

        for [l:alias_left, l:alias_right] in items(l:paths_map)
            let l:alias_left = substitute(l:alias_left , '\*$', '', '')
            if a:module =~ '^' . l:alias_left
                for l:right_item in l:alias_right
                    let l:right_item = substitute(l:right_item, '\*$', '', '')
                    let l:resolved_path = resolve(
                        \ l:base_url .
                        \ '/' .
                        \ l:right_item .
                        \ substitute(a:module, '^' . l:alias_left, '', '')
                        \)
                    let l:resolved_path = fnamemodify(l:resolved_path, ':p')
                    
                    if !empty(l:resolved_path)
                        return s:ResolveFile(fnamemodify(l:resolved_path, ':.'))
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

function! s:FindModule(selecting_module_str)
    " regard selection as a module string, this is a backup solution
    if a:selecting_module_str
        let l:old_x_reg = getreg('x')
        silent execute 'normal! gv"xy'
        let l:selected_text = getreg('x')
        call setreg('x', l:old_x_reg)
        let l:cleaned = substitute(l:selected_text, '[''"(){};,\[\]\n]', '', 'g')
        if !empty(l:cleaned)
            return {"module": l:cleaned, "search": ''}
        endif
    endif

    " check: import('xxx')
    " not respecting separated in two lines
    let l:match = matchlist(getline('.')[col('.') - 1 : ], '\vimport\(\s{-}[''"](.{-})[''"]\s{-}\)')
    if empty(l:match)
        let l:match = matchlist(getline('.'), '\vimport\(\s{-}[''"](.{-})[''"]\s{-}\)')
    endif
    if !empty(l:match)
        return {"module": l:match[1], "search": ''}
    endif

    " check: require('xxx') or require<Type>('xxx')
    " not respecting separated in two lines
    let l:match = matchlist(getline('.')[col('.') - 1 : ], '\vrequire(\<.{-}\>)?\(\s{-}[''"](.{-})[''"]\s{-}\)')
    if empty(l:match)
        let l:match = matchlist(getline('.'), '\vrequire(\<.{-}\>)?\(\s{-}[''"](.{-})[''"]\s{-}\)')
    endif
    if !empty(l:match)
        return {"module": l:match[2], "search": ''}
    endif

    " check: import 'xxx'
    " not respecting separated in two lines
    let l:match = matchlist(getline('.'), '\vimport\s+[''"](.{-})[''"]')
    if !empty(l:match)
        return {"module": l:match[1], "search": ''}
    endif

    " check: ... from 'xxx'
    " not respecting separated in two lines
    let l:max_test_lines = 5000
    for l:i in range(line('.'), line('.') + l:max_test_lines)
        let l:line_content = getline(l:i)
        let l:match = matchlist(l:line_content, '\vfrom\s+[''"](.{-})[''"]')

        if !empty(l:match)
            return {"module": l:match[1], "search": ''}
        endif
    endfor

    " check: current word is a imported value from some module
    let l:current_word = expand('<cword>')
    if empty(l:current_word)
        return {"module": '', "search": ''}
    endif

    let l:view = winsaveview()
    let l:module = ''
    normal! gg
    let @/= '\<' . l:current_word . '\>'
    normal! n
    call histadd('search', @/)
    for l:i in range(line('.'), line('.') + l:max_test_lines)
        let l:line_content = getline(l:i)
        let l:match = matchlist(l:line_content, '\vfrom\s+[''"](.{-})[''"]')

        if !empty(l:match)
            let l:module = l:match[1]
            break
        endif
    endfor
    call winrestview(l:view)
    if !empty(l:match)
        return {"module": l:module, "search": l:current_word}
    endif
endfunction


function! GotoModuleTs(args)
    let l:use_custom_tsconfig = get(a:args, 'use_custom_tsconfig', 1)
    let l:selecting_module_str = get(a:args, 'selecting_module_str', 0)
    let l:open_in_new_window = get(a:args, 'open_in_new_window', 0)

    let l:found = s:FindModule(l:selecting_module_str)

    if !empty(l:found.module)
        let l:resolved_paths = s:ResolvePath(l:found.module, l:use_custom_tsconfig)

        if !empty(l:resolved_paths)
            if len(l:resolved_paths) == 1
                if a:open_in_new_window
                    execute 'vs' l:resolved_paths[0]
                else
                    execute 'edit' l:resolved_paths[0]
                endif
                if !empty(l:found.search)
                    let @/= '\<' . l:found.search . '\>'
                    silent! normal! n
                    call histadd('search', @/)
                endif
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
                    if a:open_in_new_window
                        execute 'vs' l:resolved_paths[l:choice - 1]
                    else
                        execute 'edit' l:resolved_paths[l:choice - 1]
                    endif
                    if !empty(l:found.search)
                        let @/= '\<' . l:found.search . '\>'
                        silent! normal! n
                        call histadd('search', @/)
                    endif
                endif
            endif
        else
            echohl ErrorMsg
            echom "Error: Could not resolve path for module: " . l:found.module
            echohl None
        endif
    else
        echohl ErrorMsg
        echom "Error: No import module statement found"
        echohl None
    endif
endfunction
