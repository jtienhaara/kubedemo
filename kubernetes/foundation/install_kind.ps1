# WARNING I have not tested this script.  User discretion is advised.

$KIND_VERSION = "0.20.0"

# Download kind from k8s.io:
curl.exe --location --output kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v$KIND_VERSION/kind-windows-amd64

# Move kind to Program Files
New-Item -Path "$env:SystemDrive\Program Files\kind" -ItemType Directory
Move-Item .\kind-windows-amd64.exe "$env:SystemDrive\Program Files\kind\kind.exe"

# Add kind to PATH
$newPath = "$env:SystemDrive\Program Files\kind\kind.exe;" + $env:PATH
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::Machine)
