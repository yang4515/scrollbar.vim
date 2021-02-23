let s:ns_id = nvim_create_namespace('scrollbar')

function! s:gen_bar_lines(size) abort
  let lines = ['▲']
  for _ in range(2, a:size - 1)
    call add(lines, '█')
  endfor
  call add(lines, '▼')
  return lines
endfunction

function! s:buf_get_var(bufnr, name) abort
  try
    let var = nvim_buf_get_var(a:bufnr, a:name)
    return var
  catch
  endtry
endfunction

let s:next_index = 0
function! s:next_buf_index() abort
  let s:next_index += 1
  return s:next_index - 1
endfunction

function! s:create_buf(size, lines) abort
  noautocmd let bufnr = nvim_create_buf(0, 1)
  noautocmd call nvim_buf_set_option(bufnr, 'filetype', 'scrollbar')
  noautocmd call nvim_buf_set_name(bufnr, 'scrollbar_' . s:next_buf_index())
  noautocmd call nvim_buf_set_lines(bufnr, 0, a:size, 0, a:lines)
  return bufnr
endfunction

function! s:show(...) abort
  let winnr = get(a:000, 0, 0)
  let bufnr = get(a:000, 1, 0)
  let win_config = nvim_win_get_config(winnr)

  if win_config.relative !=# ''
    return
  endif

  let filetype = nvim_buf_get_option(bufnr, 'filetype')

  if filetype == ''
    return
  endif

  let total = line('$')
  let height = nvim_win_get_height(winnr)
  if total <= height
    call replace#clear()
    return
  endif

  let cursor = nvim_win_get_cursor(winnr)
  let curr_line = cursor[0]
  let bar_size = height * height / total
  let bar_size = max([3, min([100, bar_size])])

  let width = nvim_win_get_width(winnr)
  let col = width - 2
  let row = (height - bar_size) * (curr_line * 1.0  / total)

  let opts = { 'style': 'minimal', 'relative': 'win', 'win': winnr, 'width': 1, 'height': bar_size, 'row': row, 'col': col, 'focusable': 0 }
  let [bar_winnr, bar_bufnr] = [0, 0]
  let state = s:buf_get_var(bufnr, 'scrollbar_state')
  if !empty(state)
    let bar_bufnr = state.bufnr
    if has_key(state, 'winnr') && win_id2win(state.winnr) > 0
      let bar_winnr = state.winnr
    else
      noautocmd let bar_winnr = nvim_open_win(bar_bufnr, 0, opts)
    endif
    if state.size !=# bar_size
      noautocmd call nvim_buf_set_lines(bar_bufnr, 0, -1, 0, [])
      let bar_lines = s:gen_bar_lines(bar_size)
      noautocmd call nvim_buf_set_lines(bar_bufnr, 0, bar_size, 0, bar_lines)
    endif
    noautocmd call nvim_win_set_config(bar_winnr, opts)
  else
    let bar_lines = s:gen_bar_lines(bar_size)
    let bar_bufnr = s:create_buf(bar_size, bar_lines)
    let bar_winnr = nvim_open_win(bar_bufnr, 0, opts)
    call nvim_win_set_option(bar_winnr, 'winhl', 'Normal:ScrollbarWinHighlight')
  endif
  call nvim_buf_set_var(bufnr, 'scrollbar_state', { 'winnr': bar_winnr, 'bufnr': bar_bufnr, 'size': bar_size })
  return [bar_winnr, bar_bufnr]
endfunction

" the first argument is buffer number
function! s:clear(...) abort
  let bufnr = get(a:000, 0, 0)
  let state = s:buf_get_var(bufnr, 'scrollbar_state')
  if !empty(state) && has_key(state, 'winnr')
    if win_id2win(state.winnr) > 0
      noautocmd call nvim_win_close(state.winnr, 1)
    endif
    noautocmd call nvim_buf_set_var(bufnr, 'scrollbar_state', { 'size': state.size, 'bufnr': state.bufnr })
  endif
endfunction

function! scrollbar#do()
  autocmd BufEnter,CursorMoved,FocusGained * call s:show()
  autocmd BufLeave,FocusLost,QuitPre * call s:clear()
endfunction
