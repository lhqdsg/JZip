@echo off
setlocal EnableExtensions
setlocal enabledelayedexpansion
chcp 936 >nul

::调用
if /i "%1"=="" call :Wizard Install
if /i "%1"=="-upgrade" call :Wizard Upgrade
if /i "%1"=="-uninstall" call :Wizard UnInstall
if /i "%1"=="-install" start "" cmd /c ""%dir.jzip%\Jzip.cmd" -install"
goto :EOF

:Wizard
title Jzip Installer
cls

:: 预设错误代码
set "if.error.lm=您可以在 https://github.com/Dennishaha/JZip 上了解更多信息。"
set "if.error.1=|| ( call :MsgBox "取得 安装信息 失败。" "%if.error.lm%" & goto :EOF )"
set "if.error.2=|| ( call :MsgBox "下载的文件不存在，请重新尝试。" "%if.error.lm%" & goto :EOF )"
set "if.error.3=|| ( call :MsgBox "更新包出现错误，请重新尝试。" "%if.error.lm%" & goto :EOF )"
set "if.error.4=|| ( call :MsgBox "缺失 Bitsadmin 组件，在早期版本 Windows 中不存在。" "%if.error.lm%" & goto :EOF )"

:: 安装时，配置路径和窗口
if "%1"=="Install" (
	set "dir.jzip=%appdata%\JFsoft\JZip\App"
	set "dir.jzip.temp=%temp%\JFsoft.JZip"
	>nul 2>nul md !dir.jzip.temp!
	mode 80, 25
	color f0
)
	
:: 检测 Bits 组件
bitsadmin /? >nul 2>nul %if.error.4%

:: 若 Bits 服务被禁用，询问开启
sc qc bits | findstr /i "DISABLED" >nul && (
	if "%1"=="Install" call :MsgBox-s key "Jzip 安装过程需要 Bits 服务。" " 您是否允许 Jzip 启用服务？"
	if "%1"=="Upgrade" call :MsgBox-s key "Jzip 更新过程需要 Bits 服务。" "您是否允许 Jzip 启用服务？"
	
	if "!key!"=="1" (
		:: 启用 Bits 服务
		net session >nul 2>nul && (sc config bits start= demand >nul)
		net session >nul 2>nul || (
			mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("cmd.exe","/c sc config bits start= demand >nul","","runas",1^)^(window.close^)
		)
		ping localhost -n 2 >nul
	) else (
		call :MsgBox "抱歉，无法安装 JZip。" "%if.error.lm%"
		goto :EOF
	)
)

:: 获取 Github 上的 JZip 安装信息
for %%a in (Install Upgrade) do if "%1"=="%%a" (
	dir "%dir.jzip.temp%\ver.ini" /a:-d /b >nul 2>nul && del /q /f /s "%dir.jzip.temp%\ver.ini" >nul 2>nul
	bitsadmin /transfer !random! /download /priority foreground https://raw.githubusercontent.com/Dennishaha/JZip/master/Server/ver.ini "%dir.jzip.temp%\ver.ini" %if.error.1%
	cls
	dir "%dir.jzip.temp%\ver.ini" /a:-d /b >nul 2>nul %if.error.2%

	for /f "eol=[ usebackq tokens=1,2* delims==" %%a in (`type "%dir.jzip.temp%\ver.ini"`) do set "%%a=%%b"
	set "jzip.newver.page=%dir.jzip.temp%\full.!jzip.newver!.exe"
)

::UI--------------------------------------------------

cls
echo.
echo.
echo.

if "%1"=="Install" echo.      现在可以安装 Jzip %jzip.newver%
if "%1"=="Upgrade" if /i not "%jzip.ver%"=="%jzip.newver%" echo.      现在可以获取新版本 JZip %jzip.newver%

for %%a in (Install Upgrade) do if "%1"=="%%a" if /i not "%jzip.ver%"=="%jzip.newver%" (
	echo. & echo.
	:describe_split
	for /f "tokens=1,* delims=;" %%a in ("!jzip.newver.describe!") do (
		set "jzip.newver.describe=%%b"
		echo.      %%~a
	)
	if not "!jzip.newver.describe!"=="" goto :describe_split
)

::UI--------------------------------------------------

:: 弹出选择
if "%1"=="Install" call :MsgBox-s key "现在可以安装 Jzip %jzip.newver%。"
if "%1"=="UnInstall" call :MsgBox-s key "确实要卸载 JZip 吗？"
if "%1"=="Upgrade" if /i "%jzip.ver%"=="%jzip.newver%" call :MsgBox "JZip %jzip.ver% 是最新的。" & goto :EOF
if "%1"=="Upgrade" if /i not "%jzip.ver%"=="%jzip.newver%" call :MsgBox-s key "现在可以获取新版本 JZip %jzip.newver%。"
if not "%key%"=="1" goto :EOF

:: 获取 JZip 安装包
for %%a in (Install Upgrade) do  if "%1"=="%%a" (
	dir "%jzip.newver.page%" /a:-d /b >nul 2>nul && del /q /f /s "%jzip.newver.page%" >nul 2>nul
	bitsadmin /transfer %random% /download /priority foreground %jzip.newver.url% "%jzip.newver.page%" %if.error.1%
	cls
	dir "%jzip.newver.page%" /a:-d /b >nul 2>nul %if.error.2%
	"%jzip.newver.page%" t | findstr "^Everything is Ok" >nul 2>nul %if.error.3%
)

:: 解除安装
for %%a in (UnInstall Upgrade) do if "%1"=="%%a" (
	call "%dir.jzip%\Parts\Set_Lnk.cmd" -off all
	call "%dir.jzip%\Parts\Set_Assoc.cmd" & if "!tips.FileAssoc!"=="●" call "%dir.jzip%\Parts\Set_Assoc.cmd" -off
)

:: 安装
for %%a in (Install Upgrade) do if "%1"=="%%a" (
	cmd /q /c "rd /q /s "%dir.jzip%" >nul 2>nul & md "%dir.jzip%" >nul 2>nul & "%jzip.newver.page%" x -o"%dir.jzip%\" & "%dir.jzip%\%jzip.newver.installer%" -install"
	exit
)

:: 删除 JZip 目录
if "%1"=="UnInstall" (
	reg delete "HKCU\Software\JFsoft.Jzip" /f >nul
	cmd /q /c "rd /q /s "%dir.jzip%"  >nul 2>nul"
)
goto :EOF



:: 插件
:MsgBox
mshta vbscript:execute^("msgbox(""%~1""&vbCrLf&vbCrLf&""%~2"",64,""提示"")(window.close)"^)
goto :EOF

:MsgBox-s
set "ui.msgbox="""
:MsgBox-s_c
if not "%~2"=="" (
	set "ui.msgbox.t=%~2"
	set "ui.msgbox.t=!ui.msgbox.t:&=?&Chr(38)&?!"
	set "ui.msgbox.t=!ui.msgbox.t: =?&Chr(32)&?!"
	set "ui.msgbox.t=!ui.msgbox.t:,=?&Chr(44)&?!"

	set "ui.msgbox=!ui.msgbox!&"!ui.msgbox.t!"&vbCrLf"
	shift /2
	goto MsgBox-s_c
)
for /f "delims=" %%a in (' mshta "vbscript:CreateObject("Scripting.Filesystemobject").GetStandardStream(1).Write(msgbox(%ui.msgbox:?="%,1+64,"提示"))(window.close)" ') do (
	set "%~1=%%a"
)
goto :EOF
