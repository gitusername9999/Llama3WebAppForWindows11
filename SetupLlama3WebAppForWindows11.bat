@echo OFF
setlocal enabledelayedexpansion

echo Setting LongPathsEnabled...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f & timeout /t 2

echo Checking LongPathsEnabled...
for /F "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled') do (
    set Value=%%b
)
if "%Value%"=="0x1" (
    echo Long Paths are enabled.
) else (
    echo Long Paths are not enabled.
)

REM Set Docker PATH temporarily
set "DOCKER_PATH=C:\Program Files\Docker\Docker\resources\bin"
set "PATH=%DOCKER_PATH%;%PATH%"
echo Setting PATH temporarily...
echo PATH set to: !PATH!
timeout /t 2

echo Setting PATH permanently...
setx PATH "%PATH%" /M
timeout /t 2

echo System Path = !PATH!

echo Checking if WSL is installed...
wsl --list --verbose >nul 2>&1
if errorlevel 1 (
    echo WSL is not installed.
) else (
    echo WSL is installed.
)

echo Checking whether WSL is enabled or not.
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux | findstr /C:"State : Enabled" >nul
if errorlevel 1 (
    echo WSL is not enabled.
    echo Enabling WSL...
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    echo WSL is enabled.    
) else (
    echo WSL is enabled.
)

wsl -l -v

echo Enabling Virtual Machine Platform...
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
echo Setting WSL 2 as the default version...
wsl --set-default-version 2

echo Define the download path relative to the batch file location
SET downloadPath=%~dp0

echo Verbose logging is enabled.
echo The batch file is located at: !downloadPath!

echo Set the URL for the Docker Desktop Installer
set "DOWNLOAD_URL=https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"

REM Set the destination path where you want to save the installer
set "DEST_PATH=!downloadPath!DockerDesktopInstaller.exe"

echo Checking whether Docker Desktop is installed or not.
set "DOCKER_DESKTOP_PATH=C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo DOCKER DESKTOP PATH = "!DOCKER_DESKTOP_PATH!" & timeout /t 2

if exist "!DOCKER_DESKTOP_PATH!" (
    echo Docker Desktop is installed at "!DOCKER_DESKTOP_PATH!".
) else (
    echo Docker Desktop is not installed.
    if exist "!DEST_PATH!" (
        echo DockerDesktopInstaller.exe exists at "!DEST_PATH!"
        echo No need to download it.
    ) else (
        echo DockerDesktopInstaller.exe does not exist at "!DEST_PATH!"
        echo Preparing to download DockerDesktopInstaller.exe.
        if exist "!downloadPath!DownloadDockerDesktopInstaller.ps1" (
            echo Download URL = !DOWNLOAD_URL!
            echo Download Destination = "!DEST_PATH!" & timeout /t 2
            start /wait PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '!downloadPath!DownloadDockerDesktopInstaller.ps1'"
        ) else (
            echo PowerShell script DownloadDockerDesktopInstaller.ps1 does not exist in the directory "!downloadPath!".
            pause
            exit /b
        )
    )
    echo Installing Docker Desktop ....... silently please wait for it to be done.....
    start /wait "" "!DEST_PATH!" install --quiet --accept-license
    if %ERRORLEVEL% NEQ 0 (
        echo DockerDesktopInstaller.exe possibly corrupted. Please rename it as a backup and re-run the batch file.
        pause
        exit /b
    )
    if exist "!DOCKER_DESKTOP_PATH!" (
        echo Docker Desktop installed successfully at "!DOCKER_DESKTOP_PATH!".
    ) else (
        echo Docker Desktop installation failed.
    )
)

echo Check if Docker is already running
tasklist | find /I "Docker Desktop.exe" > nul
if errorlevel 1 (
    echo Docker is not running, starting Docker Desktop in the background...
    echo Docker Desktop Path = "!DOCKER_DESKTOP_PATH!"
    start "" "!DOCKER_DESKTOP_PATH!"
    echo On the Docker Desktop Popup Survey Windows, select your desired options and click Continue.
    echo Whenever you are done selecting the Survey options and ready to continue, press ENTER key.
    pause 
    docker ps -a > nul 2>&1
    if errorlevel 1 (
        echo Wait 30 more seconds for Docker Desktop to be ready to accept commands.
        timeout /t 30
        docker ps -a > nul 2>&1
    )
) else (
    echo Docker Desktop is already running.
)

echo Check for Ollama installation and install if not present
where /R "%USERPROFILE%\AppData\Local\Programs\Ollama" Ollama.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Ollama is not installed. Preparing to install Ollama...
    echo Downloading OllamaSetup.exe to !downloadPath!
    start /wait powershell.exe -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '!downloadPath!OllamaSetup.exe'"
    echo Download complete. Running OllamaSetup.exe from !downloadPath!OllamaSetup.exe
    start /wait "" "!downloadPath!OllamaSetup.exe" /silent /norestart
    echo wait 20 seconds for Ollama installation to be ready to be used.
    timeout /t 20
) else (
    echo Ollama is already installed.
)


echo Check if Ollama is running and start if not
set OLLAMA_PATH=%USERPROFILE%\AppData\Local\Programs\Ollama\Ollama.exe
echo OLLAMA_Path is !OLLAMA_PATH!

if not exist "!OLLAMA_PATH!" (
    echo ERROR: Ollama executable not found at !OLLAMA_PATH!
    echo Please ensure Ollama is installed correctly.
    pause
    exit /b
)
tasklist | find /I "Ollama.exe" > nul
if errorlevel 1 (
    echo Ollama is not running. Starting Ollama in the background...
    echo Termining any running Ollam.exe
    start "" "!OLLAMA_PATH!"
    :waitForOllama
    tasklist /FI "IMAGENAME eq Ollama.exe" 2>nul | find /I "Ollama.exe">nul
    if %ERRORLEVEL% NEQ 0 (
        echo Waiting for Ollama to start...   
        timeout /t 2
        goto :waitForOllama
    ) else (
        echo Ollama is running in the background.
    )
) else (
    echo Ollama is already running.
)

echo Check for Llama3 image and pull if not present
FOR /F "tokens=*" %%i IN ('!OLLAMA_PATH! list ^| findstr /I "llama3:latest"') DO SET llama3Image=%%i
IF "!llama3Image!"=="" (
    echo Llama3 image is not present. Pulling Llama3 image...
    !OLLAMA_PATH! pull llama3:latest
    echo Llama3 image pulled successfully.
    echo Wait 10 seconds for llama3 to be ready
    timeout /t 10
) else (
    echo Llama3 image is already present.
)

echo Run the Docker command to start the Ollama WebUI

FOR /F "tokens=*" %%i IN ('docker ps -q -f name^=open-webui') DO SET result=%%i
IF "%result%"=="" (
    FOR /F "tokens=*" %%i IN ('docker ps -aq -f name^=open-webui') DO SET result=%%i
    IF NOT "%result%"=="" (
        echo "Container exists but is not running. Removing the container..."
        docker rm open-webui
    )
    echo "Starting the container..."
    docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
    echo Ollama WebUI started. Access it via http://localhost:3000 in your web browser.
    echo Wait 40 for the Ollama WebUI to be fully loaded.
    timeout /t 40
) ELSE (
    echo "Container is already running."
)

:: Open the default web browser and navigate to the Ollama WebUI
start http://localhost:3000

:: End of script
echo Batch process complete. Press any key to close this window.
ENDLOCAL

echo Script execution completed successfully.
pause
cmd /k
exit /b
