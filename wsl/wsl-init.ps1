function ShowHelp {
    Write-Output @"
Usage: .\xx.ps1 [options]
options:
                         # Set wsl environment.
    host                 # Also set AI development environment in windows host machine.
    -h | --help | help   # Show this help info.
"@
}



function TestCommand {
    param(
        [string]$Command,
        [string]$Arguments = ""
    )

    try
    {
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $Command
        $processStartInfo.Arguments = $Arguments
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start()
        $process.WaitForExit()

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        return @{
            HasException = $false
            StandardOutput = $stdout
            StandardError = $stderr
            ExitCode = $process.ExitCode
        }
    }
    catch {
        $exceptionErrorInfo = "Exception Type: $($_.Exception.GetType().FullName), Exception Message: ""$($_.Exception.Message)"""
        if ($_.Exception.InnerException) {
            $exceptionErrorInfo += "`nInner Exception Type: $($_.Exception.InnerException.GetType().FullName), Inner Exception Message: ""$($_.Exception.InnerException.Message)"""
        }

        return @{
            HasException = $true
            StandardOutput = ""
            StandardError = $exceptionErrorInfo
            ExitCode = -1
        }
    }
}



function InstallEnvForHost {
    Write-Output "Installing and configuring enviorment for Windows machine..."

    $arch = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    $proc = (Get-CimInstance Win32_Processor).AddressWidth
    if (!($arch -like "*64*" -and $proc -eq 64)) {
        Write-Output "Unsupported CPU architecture, Windows CUDA only supports amd64. Installing and configuring environment for Windows machine was canceled."
        return
    }
    
    # Install python
    $isPythonInstallNeeded = $true
    $pythonVersion = TestCommand -Command "python" -Arguments "--version"
    $pythonVersionOutput = $pythonVersion.StandardOutput
    if (!$pythonVersion.HasException -and $pythonVersion.ExitCode -eq 0) {
        if ($pythonVersionOutput -match '(\d+)\.(\d+)\.') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 9)) {
                $isPythonInstallNeeded = $false
            }
        }
    }

    if ($isPythonInstallNeeded) {
        Write-Host "Downloading Python 3.12..." -ForegroundColor Yellow
        $installerPath = "$env:TEMP\python-3.12.9-amd64.exe"
        try {
            $pythonUrl = "https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe"
            Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath
            Write-Host "Download Python 3.12 success!" -ForegroundColor Green
        }
        catch {
            Write-Host "Download Python 3.12 failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 10
        }

        Write-Host "Installing Python..." -ForegroundColor Yellow
        $installPython = TestCommand -Command $installerPath -Arguments "/passive InstallAllUsers=1 PrependPath=1 Include_test=0 Include_doc=0"
        Remove-Item -Path $installerPath -Force
        if ($installPython.ExitCode -ne 0) {
            Write-Error "Installing Python failed. Error: $($installPython.StandardError)"
            exit 11
        }
        
        Write-Host "Install Python 3.12 success!" -ForegroundColor Green
    }

    # Install CUDA
    $isCudaInstallNeeded = $true
    $nvccVersion = TestCommand -Command "nvcc" -Arguments "--version"
    $nvccVersionOutput = $nvccVersion.StandardOutput
    if (!$nvccVersion.HasException -and $nvccVersion.ExitCode -eq 0) {
        if ($nvccVersionOutput -match 'release\s(\d+)\.(\d+)\') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -gt 12 -or ($major -eq 12 -and $minor -ge 9)) {
                $isCudaInstallNeeded = $false
            }
        }
    }

    if ($isCudaInstallNeeded) {
        Write-Host "Downloading CUDA 12.9..." -ForegroundColor Yellow
        $installerPath = "$env:TEMP\cuda_12.9.1_576.57_windows.exe"
        try {
            $cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_576.57_windows.exe"
            Invoke-WebRequest -Uri $cudaUrl -OutFile $installerPath
            Write-Host "Download CUDA 12.9 success!" -ForegroundColor Green
        }
        catch {
            Write-Host "Download CUDA 12.9 failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 10
        }

        Write-Host "Installing CUDA..." -ForegroundColor Yellow
        $installCuda = TestCommand -Command $installerPath
        Remove-Item -Path $installerPath -Force
        if ($installCuda.ExitCode -ne 0) {
            Write-Error "Installing CUDA failed. Error: $($installCuda.StandardError)"
            exit 11
        }
        Write-Host "Install CUDA 12.9 success!" -ForegroundColor Green
    }

    # Install Pytorch

    #python -c "import torch; print('PyTorch版本:', torch.__version__)"
    #pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu129


    Write-Host "Installing and configuring enviorment for Windows machine successed." -ForegroundColor Green
}


function Init {
    param(
        [bool]$IsForHost = $false
    )

    $wslStatus = TestCommand -Command "wsl" -Arguments "--status"
    if (!$wslStatus.HasException -and $wslStatus.ExitCode -ne 0) {
        Write-Error "Wsl is available, but it does not work properly. Error: $($wslStatus.StandardError)"
        exit 3
    }

    if ($wslStatus.HasException) {
        Write-Output "Installing wsl on your Windows machine..."
        $wslInstall = TestCommand -Command "wsl" -Arguments "--install --inbox --no-distribution"
        if ($wslInstall.ExitCode -ne 0) {
            Write-Error "Installing wsl failed. Error: $($wslInstall.StandardError)"
            exit 4
        }
    }
    
    Write-Output "Updating wsl..."
    $wslUpdate = TestCommand -Command "wsl" -Arguments "--update"
    if ($wslUpdate.ExitCode -ne 0) {
        Write-Error "Update wsl failed. Error: $($wslUpdate.StandardError)"
        exit 5
    }
    $wslSetDefaultVersion = TestCommand -Command "wsl" -Arguments "--set-default-version 2"
    if ($wslSetDefaultVersion.ExitCode -ne 0) {
        Write-Error "Update wsl failed. Error: $($wslSetDefaultVersion.StandardError)"
        exit 6
    }
    
    $wslList = TestCommand -Command "wsl" -Arguments "--list --quiet"
    if ($wslList.ExitCode -ne 0) {
        Write-Error "List wsl failed. Error: $($wslList.StandardError)"
        exit 7
    }

    $wslLists =$wslList.StandardOutput
    $wslListArray = $wslLists.Split(@("`r`n", "`r", "`n"), [StringSplitOptions]::RemoveEmptyEntries) | 
                Where-Object { $_.Trim() -ne "" }
    $isUbuntu2404Found = $false
    if ($wslListArray -contains "Ubuntu-24.04") {
        $isUbuntu2404Found = $true
    }
    if (!$isUbuntu2404Found) {
        Write-Output "Installing Ubuntu 24.04 for wsl ..."
        $wslInstall = TestCommand -Command "wsl" -Arguments "--install --distribution Ubuntu-24.04 --web-download"
        if ($wslInstall.ExitCode -ne 0) {
            Write-Error "Installing Ubuntu 24.04 for wsl failed. Error: $($wslInstall.StandardError)"
            exit 8
        }
    }

    $wslSetDefault = TestCommand -Command "wsl" -Arguments "--set-default Ubuntu-24.04"
    if ($wslSetDefault.ExitCode -ne 0) {
        Write-Error "Set Ubuntu24.04 as wsl default failed. Error: $($wslSetDefault.StandardError)"
        exit 9
    }

    if ($IsForHost) {
        Write-Output "Extra setup enviorment for host machine..."
        InstallEnvForHost
    }

    Write-Output "Done!"
}



# main
if ($args.Count -gt 1) {
    Write-Error "Error: Too many arguments (>1)."
    ShowHelp
    exit 1
}

$IsForHost = $false
if ($args.Count -eq 1) {
    switch ($args[0].ToLower()) {
        "host" { $IsForHost = $true }
        { $_ -in @("-h", "--help", "help") } {
            ShowHelp
            exit 0
        }
        default {
            Write-Output "Unknown option: $($args[0])"
            ShowHelp
            exit 2
        }
    }
}

Init $IsForHost