@echo off
setlocal enabledelayedexpansion

rem Ghidra MCP - Windows local setup (see README.md Installation section)
rem Wraps: python -m tools.setup preflight | ensure-prereqs | build | deploy

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"

set "SKIP_BUILD=0"
set "GHIDRA_ARG="
set "PY_ARGS="

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="-SkipBuild" (
    set "SKIP_BUILD=1"
    shift
    goto parse_args
)
if /i "%~1"=="/SkipBuild" (
    set "SKIP_BUILD=1"
    shift
    goto parse_args
)
if /i "%~1"=="/quick" (
    set "SKIP_BUILD=1"
    shift
    goto parse_args
)
if /i "%~1"=="-Help" goto show_help
if /i "%~1"=="/?" goto show_help
if /i "%~1"=="-h" goto show_help
if not defined GHIDRA_ARG (
    set "GHIDRA_ARG=%~1"
    shift
    goto parse_args
)
echo ERROR: Unknown argument: %~1
exit /b 1

:args_done

rem Resolve Ghidra install: arg > GHIDRA_INSTALL_DIR > GHIDRA_PATH > default
if defined GHIDRA_ARG (
    set "GHIDRA_INSTALL_DIR=%GHIDRA_ARG%"
) else if not defined GHIDRA_INSTALL_DIR (
    if defined GHIDRA_PATH (
        set "GHIDRA_INSTALL_DIR=%GHIDRA_PATH%"
    ) else (
        set "GHIDRA_INSTALL_DIR=C:\tools\ghidra"
    )
)
set "GHIDRA_PATH=%GHIDRA_INSTALL_DIR%"

echo.
echo ============================================================
echo  Ghidra MCP - Windows local setup
echo  Repo:    %REPO_ROOT%
echo  Ghidra:  %GHIDRA_INSTALL_DIR%
echo ============================================================
echo.

rem Validate Ghidra installation directory
set "GHIDRA_VALID=0"
if exist "%GHIDRA_INSTALL_DIR%\ghidraRun.bat" set "GHIDRA_VALID=1"
if exist "%GHIDRA_INSTALL_DIR%\support\analyzeHeadless.bat" set "GHIDRA_VALID=1"
if "!GHIDRA_VALID!"=="0" (
    echo ERROR: Ghidra installation not found at:
    echo   %GHIDRA_INSTALL_DIR%
    echo.
    echo Expected ghidraRun.bat or support\analyzeHeadless.bat in that directory.
    echo Override with: scripts\local-setup.bat C:\path\to\ghidra
    echo Or set GHIDRA_INSTALL_DIR before running.
    exit /b 1
)

rem Prefer repo venv, then py launcher, then python on PATH
set "PYTHON="
if exist "%REPO_ROOT%\.venv\Scripts\python.exe" (
    set "PYTHON=%REPO_ROOT%\.venv\Scripts\python.exe"
) else (
    where py >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON=py"
        set "PY_ARGS=-3"
    ) else (
        set "PYTHON=python"
    )
)

echo Using Python: %PYTHON% %PY_ARGS%
echo.

call :run_setup "Step 1/4 - Environment preflight" preflight
if errorlevel 1 exit /b 1

call :run_setup "Step 2/4 - Install prerequisites - Python deps and Ghidra Maven JARs" ensure-prereqs
if errorlevel 1 exit /b 1

if "!SKIP_BUILD!"=="1" (
    echo.
    echo ============================================================
    echo  Step 3/4 - Build skipped ^(-SkipBuild / /quick^)
    echo ============================================================
    echo.
) else (
    call :run_setup "Step 3/4 - Build extension - Maven" build
    if errorlevel 1 exit /b 1
)

call :run_setup "Step 4/4 - Deploy extension to Ghidra profile" deploy
if errorlevel 1 exit /b 1

echo.
echo ============================================================
echo  Local setup completed successfully
echo ============================================================
echo.
echo Next steps (manual):
echo   1. In Ghidra CodeBrowser: File ^> Configure ^> Configure All Plugins - enable GhidraMCP
echo   2. Tools ^> GhidraMCP ^> Start MCP Server  (default http://127.0.0.1:8089/)
echo   3. Run the MCP bridge: python bridge_mcp_ghidra.py
echo   4. Point your MCP client at the bridge (see README Basic Usage)
echo.
echo Optional: copy .env.template to .env and customize GHIDRA_MCP_* settings.
echo.
exit /b 0

:run_setup
set "SETUP_STEP=%~1"
echo.
echo ============================================================
echo  !SETUP_STEP!
echo ============================================================
if /i "%~2"=="build" (
    if defined PY_ARGS (
        "%PYTHON%" %PY_ARGS% -m tools.setup build
    ) else (
        "%PYTHON%" -m tools.setup build
    )
) else if defined PY_ARGS (
    "%PYTHON%" %PY_ARGS% -m tools.setup %~2 --ghidra-path "%GHIDRA_INSTALL_DIR%"
) else (
    "%PYTHON%" -m tools.setup %~2 --ghidra-path "%GHIDRA_INSTALL_DIR%"
)
if errorlevel 1 (
    echo.
    echo ERROR: !SETUP_STEP! failed.
    exit /b 1
)
set "SETUP_STEP="
exit /b 0

:show_help
echo.
echo Usage: scripts\local-setup.bat [OPTIONS] [GHIDRA_INSTALL_DIR]
echo.
echo Automates the README first-time setup workflow via python -m tools.setup:
echo   preflight, ensure-prereqs, build, deploy
echo.
echo Ghidra path resolution (first match wins):
echo   1. First positional argument
echo   2. GHIDRA_INSTALL_DIR environment variable
echo   3. GHIDRA_PATH environment variable
echo   4. Default: C:\tools\ghidra
echo.
echo Options:
echo   -SkipBuild, /SkipBuild, /quick   Skip Maven build; deploy existing artifacts
echo   -Help, /?, -h                    Show this help
echo.
echo Examples:
echo   scripts\local-setup.bat
echo   scripts\local-setup.bat C:\tools\ghidra
echo   set GHIDRA_INSTALL_DIR=C:\tools\ghidra ^& scripts\local-setup.bat /quick
echo.
exit /b 0
