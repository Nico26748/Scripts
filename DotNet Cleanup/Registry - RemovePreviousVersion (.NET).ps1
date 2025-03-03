# Taken From: JSG - Enable Registry Key for .Net remove old version
# Set Registry Values to Remove Previous Versions After Update

[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NET", "RemovePreviousVersion", "always")
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\dotnet", "RemovePreviousVersion", "always")
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework", "RemovePreviousVersion", "always")
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ASP.NET Core\Shared Framework", "RemovePreviousVersion", "always")