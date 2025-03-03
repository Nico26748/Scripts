Param (
    [Parameter(Mandatory=$true)] [string] $Code
)

msiexec.exe /X $Code /qn /norestart