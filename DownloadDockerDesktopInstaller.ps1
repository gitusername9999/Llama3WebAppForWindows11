# Define the user agent to simulate a browser request
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
Write-Host "User agent set for the download request."

# Use Shell.Application to get the path of the Downloads folder
$shell = New-Object -ComObject Shell.Application
$downloadsFolder = "$PSScriptRoot"

Write-Host "Downloads folder path determined: $downloadsFolder"

# Specify the path where the Docker installer will be downloaded
$installerPath = "$downloadsFolder\DockerDesktopInstaller.exe"
Write-Host "Installer will be downloaded to: $installerPath"

# Download the Docker Desktop installer
try {
   # Write-Host "Attempting to download Docker Desktop Installer..."
   Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile $installerPath -UserAgent $userAgent
   Write-Host "Docker Desktop Installer downloaded successfully."
} catch {
   Write-Host "Error: Unable to download Docker Desktop Installer."
   # exit
}

# Ensure the installer file exists before attempting to run it
if (Test-Path -Path $installerPath) {
    Write-Host "Installer file found. Proceeding with installation..."
    # Commenting out the installation part as requested
    # Start-Process -FilePath $installerPath -ArgumentList "/install", "/quiet", "/norestart" -Wait
    # Write-Host "Docker installation process completed."

    # Rest of the script remains unchanged...
}
