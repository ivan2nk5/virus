@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_URL=https://github.com/OWNER/REPO.git"
set "BRANCH=main"
set "PROJECT_DIR=%~dp0project"
set "ENTRYPOINT=main.py"
set "VENV_DIR=.venv"
set "LOG_FILE=%~dp0setup_log.txt"

set "PYTHON_VERSION=3.8.10"
set "PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe"
set "PYTHON_INSTALLER=%TEMP%\python-%PYTHON_VERSION%-amd64.exe"
set "PYTHON_EXE=%LocalAppData%\Programs\Python\Python38\python.exe"

set "PS=powershell -NoProfile -ExecutionPolicy Bypass -Command"

call :log "=============================="
call :log "Setup started: %DATE% %TIME%"
call :log "REPO_URL=%REPO_URL%"
call :log "BRANCH=%BRANCH%"
call :log "PROJECT_DIR=%PROJECT_DIR%"
call :log "ENTRYPOINT=%ENTRYPOINT%"
call :log "=============================="

call :log "Step: download project"

set "HAS_GIT=0"
where git >nul 2>nul && set "HAS_GIT=1"

if "%HAS_GIT%"=="1" (
  call :log "Git found"
  if exist "%PROJECT_DIR%\.git" (
    call :log "Repository already exists, updating"
    pushd "%PROJECT_DIR%" || call :fail "Cannot enter project directory"
    git fetch --all >> "%LOG_FILE%" 2>&1 || call :fail "git fetch failed"
    git checkout "%BRANCH%" >> "%LOG_FILE%" 2>&1 || call :fail "git checkout failed"
    git pull >> "%LOG_FILE%" 2>&1 || call :fail "git pull failed"
    popd
  ) else (
    call :log "Cloning repository"
    if exist "%PROJECT_DIR%" rmdir /s /q "%PROJECT_DIR%" >nul 2>nul
    git clone --branch "%BRANCH%" "%REPO_URL%" "%PROJECT_DIR%" >> "%LOG_FILE%" 2>&1 || call :fail "git clone failed"
  )
) else (
  call :log "Git not found, downloading ZIP"

  set "REPO_WEB=%REPO_URL%"
  if /i "!REPO_WEB:~-4!"==".git" set "REPO_WEB=!REPO_WEB:~0,-4!"
  set "ZIP_URL=!REPO_WEB!/archive/refs/heads/%BRANCH%.zip"

  set "TMP_DIR=%TEMP%\repo_%RANDOM%%RANDOM%"
  set "ZIP_FILE=!TMP_DIR!\repo.zip"
  set "UNZIP_DIR=!TMP_DIR!\unzipped"

  mkdir "!TMP_DIR!" >nul 2>nul || call :fail "Cannot create temp directory"
  mkdir "!UNZIP_DIR!" >nul 2>nul || call :fail "Cannot create unzip directory"

  call :log "ZIP_URL=!ZIP_URL!"

  %PS% "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('!ZIP_URL!', '!ZIP_FILE!')" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "ZIP download failed"  =

  %PS% "$shell = New-Object -ComObject Shell.Application; $zip = $shell.NameSpace('!ZIP_FILE!'); $dst = $shell.NameSpace('!UNZIP_DIR!'); if ($zip -eq $null) { exit 1 }; $dst.CopyHere($zip.Items(), 16); Start-Sleep -Seconds 5" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "ZIP unzip failed"

  set "EXTRACTED="
  for /d %%D in ("!UNZIP_DIR!\*") do (
    set "EXTRACTED=%%~fD"
    goto got_extracted
  )

  :got_extracted
  if not defined EXTRACTED call :fail "Extracted folder not found"

  if exist "%PROJECT_DIR%" rmdir /s /q "%PROJECT_DIR%" >nul 2>nul
  xcopy "!EXTRACTED!" "%PROJECT_DIR%\" /E /I /Y >> "%LOG_FILE%" 2>&1 || call :fail "Copy extracted project failed"
)

call :log "Step: find Python"

set "PY_CMD="

if exist "%PYTHON_EXE%" set "PY_CMD=%PYTHON_EXE%"
if not defined PY_CMD py -3.8 -V >nul 2>nul && set "PY_CMD=py -3.8"
if not defined PY_CMD py -3 -V >nul 2>nul && set "PY_CMD=py -3"
if not defined PY_CMD python -V >nul 2>nul && set "PY_CMD=python"

if not defined PY_CMD (
  call :log "Python not found, downloading Python %PYTHON_VERSION%"

  %PS% "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%PYTHON_URL%', '%PYTHON_INSTALLER%')" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "Python download failed"

  call :log "Installing Python"
  "%PYTHON_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_launcher=1 >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "Python install failed"

  if exist "%PYTHON_EXE%" set "PY_CMD=%PYTHON_EXE%"
  if not defined PY_CMD py -3.8 -V >nul 2>nul && set "PY_CMD=py -3.8"
  if not defined PY_CMD python -V >nul 2>nul && set "PY_CMD=python"

  if not defined PY_CMD call :fail "Python installed, but not found in this session"
)

call :log "Python command: %PY_CMD%"

call :log "Step: create venv, install dependencies, run project"

pushd "%PROJECT_DIR%" || call :fail "Cannot enter project directory"

if not exist "%VENV_DIR%\Scripts\python.exe" (
  call :log "Creating virtual environment"
  %PY_CMD% -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "venv creation failed"
) else (
  call :log "venv already exists"
)

call "%VENV_DIR%\Scripts\activate.bat" >> "%LOG_FILE%" 2>&1
if errorlevel 1 call :fail "venv activation failed"

python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if errorlevel 1 call :fail "pip upgrade failed"

if exist "requirements.txt" (
  call :log "Installing requirements.txt"
  pip install -r requirements.txt >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "requirements install failed"
) else if exist "pyproject.toml" (
  call :log "Installing pyproject.toml project"
  pip install . >> "%LOG_FILE%" 2>&1
  if errorlevel 1 call :fail "project install failed"
) else (
  call :log "No requirements.txt or pyproject.toml found"
)

if not exist "%ENTRYPOINT%" call :fail "Entry file not found: %ENTRYPOINT%"

call :log "Running project"
python "%ENTRYPOINT%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 call :fail "project run failed"

popd
call :log "Setup finished OK"
echo OK. Done.
pause
exit /b 0

:log
>> "%LOG_FILE%" echo [%DATE% %TIME%] %*
echo %*
exit /b 0
:fail
call :log "ERROR: %*"
echo.
echo ERROR: %*
echo See log: %LOG_FILE%
echo.
pause
exit /b 1