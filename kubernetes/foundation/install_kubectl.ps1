# WARNING I have not tested this script.  User discretion is advised.

$KUBECTL_VERSION = "1.29.1"

$KUBECTL_URL = "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/windows/amd64/kubectl.exe"

# Download kubectl from k8s.io:
curl.exe -Lo kubectl.exe $KUBECTL_URL

# Move kubectl to Program Files:
New-Item -Path "$env:SystemDrive\Program Files\kubectl" -ItemType Directory
Move-Item .\kubectl.exe "$env:SystemDrive\Program Files\kubectl\kubectl.exe"

# Add kubdectl to PATH
$newPath = "$env:SystemDrive\Program Files\kubectl\kubectl.exe;" + $env:PATH
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::Machine)
