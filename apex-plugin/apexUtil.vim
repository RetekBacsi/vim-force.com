" File: apexUtil.vim
" Author: Andrey Gavrikov 
" Version: 1.0
" Last Modified: 2012-03-05
" Copyright: Copyright (C) 2010-2012 Andrey Gavrikov
"            Permission is hereby granted to use and distribute this code,
"            with or without modifications, provided that this copyright
"            notice is copied with it. Like anything else that's free,
"            this plugin is provided *as is* and comes with no warranty of any
"            kind, either expressed or implied. In no event will the copyright
"            holder be liable for any damages resulting from the use of this
"            software.
"
" Various utility methods used by different parts of force.com plugin 
" Part of vim/force.com plugin
"
"
if exists("g:loaded_apexUtil") || &compatible
  finish
endif
let g:loaded_apexUtil = 1

if !exists("g:apex_diff_cmd") 
	if has("unix")
		" use Meld by default
		let g:apex_diff_cmd="/usr/bin/meld"
	else
		" echoerr 'please define command for diff tool'
	endif 
endif	

" compare file give as argument a:1 with its version given as a:2
" If a:2 is not specified then compare source file with same file from another
" project, assuming project structure of left and right projects is equal and
" they have common parent folder
function! ApexCompare(...)
	let leftFilePath = '' 
	if a:0 >0
		let leftFilePath = a:1
	else
		" use current file
		let leftFilePath = expand("%:p")
	endif	

	if a:0 >1
		let rightFilePath = a:2
	else	
		let rightFilePath = apexUtil#selectCounterpartFromAnotherProject(leftFilePath)
	endif	
	if len(rightFilePath) < 1
		echo 'comparison cancelled'
		return ""
	endif
	
	if executable(g:apex_diff_cmd)
		let scriptPath = shellescape(g:apex_diff_cmd)
		"let command = scriptPath.' '.shellescape(leftFilePath).' '.shellescape(rightFilePath)
		let command = scriptPath.' '.apexOs#shellescape(leftFilePath).' '.apexOs#shellescape(rightFilePath)
		"echo "command=".command
	
		":exe "!".command
		call apexOs#exe(command, 'b')
	else
		" use built-in diff
		:exe "vert diffsplit ".substitute(rightFilePath, " ", "\\\\ ", "g")
	endif
endfunction
" define command to call for current file
"command! -nargs=? ApexCompare :call ApexCompare(<args>)

" utility function to display highlighted warning message
function! apexUtil#warning(text)
	echohl WarningMsg
	echomsg a:text
	echohl None 
endfun	
"
" utility function to display highlighted info message
function! apexUtil#info(text)
	echohl Question
	echomsg a:text
	echohl None 
endfun	
"
" utility function to display highlighted error message
function! apexUtil#error(text)
	echohl ErrorMsg
	echomsg a:text
	echohl None
endfun	

" create Git repo for current Apex project and add files
function! apexUtil#gitInit()
	if !executable('git')
		echomsg 'force.com plugin: Git (http://git-scm.com/) ' .
                \ 'not found in PATH. apexUtil#gitInit() is not available.'
		finish
	endif	

	let filePath = expand("%:p")
	let projectPair = apex#getSFDCProjectPathAndName(filePath)
	let projectPath = projectPair.path
	let projectSrcPath = apex#getApexProjectSrcPath(filePath)
	echo "projectPath=".projectPath
	let supportedFiles = {'labels': 'labels', 'pages': 'page', 'classes' : 'cls', 'triggers' : 'trigger', 'components' : 'component', 'staticresources' : 'resource'}

	let response = input('Init new Git repository at: "'.projectPath.'" [a/y/n]? ')
	if 'y' == response || 'Y' == response || 'a' == response || 'A' == response
		call apexOs#exe("git init '".projectPath."'")
	endif	
	let dirs =keys(supportedFiles)
	for dirName in dirs
		" echo dirName
		let fullPath = apexOs#joinPath([projectSrcPath, dirName])
		if isdirectory(fullPath)
			let fileExtention = supportedFiles[dirName]
			let maskPath = "'".fullPath."/*.".fileExtention."'"
			if  'a' != response && 'A' != response
				let response = input('add files: "'.maskPath.'" [a/y/n]? ')
			endif

			if 'y' == response || 'Y' == response || 'a' == response || 'A' == response
				call apexOs#exe("git add ".maskPath)
			endif	
		else
			" echo fullPath." is not existing directory"
		endif
	endfor	

endfunction
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" compare current version of the file with last version backed up before
" refresh
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! apexUtil#compareWithPreRefreshVersion (apexBackupFolder)
	
	" use current file
	let leftFilePath = expand("%:p")
	let leftFileName = expand("%:t")

	if len(a:apexBackupFolder) <1
		echoerr "parameter 1: apexBackupFolder is required"
		return
	endif	
	" open folder selection dialogue
	let projectPair = apex#getSFDCProjectPathAndName(leftFilePath)
	let projectPath = projectPair.path
	let projectName = projectPair.name
	let backupRoot = apexOs#joinPath([a:apexBackupFolder, projectName])
	let rightProjectPath = apexOs#browsedir("Select folder from Backup to compare with", backupRoot)

	if len(rightProjectPath) <1
		"cancelled
		return
	endif

	let rightFilePath = apexOs#joinPath([rightProjectPath, leftFileName])
	if !filereadable(rightFilePath)
		echohl WarningMsg | echo "file ".rightFilePath." is not readable or does not exist" | echohl None
		return
	endif	

	call ApexCompare(leftFilePath, rightFilePath)

endfunction	

" using given filepath return path to the same file but in another project
" selected by user via Folder selection dialogue
function! apexUtil#selectCounterpartFromAnotherProject(filepath)
	let leftFile = a:filepath
	"echo "leftFile=".leftFile
	let projectPair = apex#getSFDCProjectPathAndName(leftFile)
	let leftProjectName = projectPair.name
	let filePathRelativeProjectFolder = strpart(leftFile, len(projectPair.path))
	"echo "projectPair.path=".projectPair.path

	let rootDir = apexOs#splitPath(projectPair.path).head
	"let rightProjectPath = browsedir("Select Root folder of the Project to compare with", rootDir)
	let rightProjectPath = apexOs#browsedir('Please select project to compare with:', rootDir)
	"echo "rightProjectPath ".rightProjectPath

	if len(rightProjectPath) <1 
		" cancelled
		return ""
	endif
	let rightFilePath = apexOs#joinPath([rightProjectPath, filePathRelativeProjectFolder])
	"echo "rightFilePath=".rightFilePath
	return rightFilePath
endfunction

"	@deprecated, use apexOs#hasTrailingPathSeparator instead
function! apexUtil#hasTrailingPathSeparator(filePath)
	return apexOs#hasTrailingPathSeparator(a:filePath)
endfunction	

"	@deprecated, use apexOs#joinPath instead
function! apexUtil#joinPath(filePathList)
	return  apexOs#joinPath(a:filePathList)
endfunction	

function! apexUtil#trim(str)
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

" check if file contains given regualr expression
" Param: expr - regular expression
" Return: 1 if found, -1 otherwise
function! apexUtil#grepFile(fileName, expr)
	try
		exe "noautocmd 1vimgrep /".a:expr."/j ".escape(a:fileName, ' \')
		"echomsg "expression found" 
		return 1
	"catch  /^Vim\%((\a\+)\)\=:E480/
	catch  /.*/
		"echomsg "expression NOT found" 
	endtry
	return -1
endfunction

" display menu and return value of selected option
" Param: prompt - e.g. "Select one of following:"
" Param: options - 
"		- list of lists, each sub-list is one menu item
"			each sub-list represents: ['return value', 'display value']
"			[["a","option a"], ["b","option B"], ["default","something else"]]
"		OR
"		- list of values, where each value represents both "value" and "label"
"		   e.g. ['apple', 'orange', 'banana']
" Return: if valid element was selected then "return value" of that element,
"			otherwise value of "default"
function! apexUtil#menu(prompt, options, default)

	call apexUtil#info(a:prompt)

	let i = 1
	for elem in a:options
		let item = []
		let isList = (3 == type(elem))
		if !isList
			" this is a string value, so use it as 'value' and as 'label'
			let item = [elem, elem]
		else
			let item = elem
		endif	
		let itemText = item[1]
		if item[0] == a:default
			let itemText .= ' *'
		endif
		echo i.". ".itemText
		let i += 1
	endfor


	let res = 'nothing'
	while len(res) > 0
		let res = input('Type number and <Enter> (empty defaults to "'.a:default.'"): ')
		if res > 0 && res <= len(a:options)
			echo ""
			if isList
				return a:options[res-1][0]
			else
				return a:options[res-1]
			endif	
		endif
	endwhile
	echo ""
	return a:default
endfunction	

