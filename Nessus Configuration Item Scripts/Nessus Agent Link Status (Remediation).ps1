# Taken from: MSB - Software - Nessus - Relink Agent with Bad Link or Bad Agent Name
# Hardcoded for <DEPTARTMENT>

$log_location = "<LOG_FOLDER_GOES_HERE>"
$log_name = "<LOG_NAME_GOES_HERE>.log"
$log_file = $log_location + "\" + $log_name
$log_process = "NessusCLI"

function log-event
{
    Param ( [String] $log_file, [String] $log_process, [String] $log_event, [String] $log_details = "", [String] $delim = ";", [String] $append = $true)
    if(-not (Test-Path $log_location)) { New-Item -Path $log_location -ItemType "directory" | out-null }
    $d = Get-Date -Format "MM/dd/yyy HH:mm:ss"
    $evt= $log_process + $delim + $d + $delim + $log_event + $delim + $log_details
    if ($append) { $evt | Out-File -Filepath $log_file -Append }
    else { $evt | Out-File -Filepath $log_file }
}

if (Test-Path -Path "C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe")
{
    $log_process = "NessusCLI"
    $scriptblock = {C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe agent status --show-uuid}
    $out = Invoke-Command -scriptblock $scriptblock # save output to variable to keep it from showing up in script results

    if ($out[2] -like "*Not linked to a manager*")
    {
        $scriptBlock = {C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe agent link --GROUPS="<GROUPS_GO_HERE>" --host="<HOST_ADDR_GOES_HERE>" --port=<PORT_GOES_HERE> --key=<KEY_GOES_HERE> --offline-install="yes"} 
        Invoke-Command -Scriptblock $scriptBlock

        Start-Sleep -s 10
        $scriptBlock = {C:\Windows\system32\net stop "Tenable Nessus Agent"} 
        Invoke-Command -Scriptblock $scriptBlock

        Start-Sleep -s 30
        $scriptBlock = {C:\Windows\system32\net start "Tenable Nessus Agent"} 
        Invoke-Command -Scriptblock $scriptBlock

        Start-Sleep -s 30
        $scriptblock = {C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe agent status --show-uuid}
        $out = Invoke-Command -scriptblock $scriptblock # save output to variable to keep it from showing up in script results
    }

    $out[2]
    $out2 = ""
    foreach($o in $out)
    {
        $x = $o.IndexOf(":")
        $prop = $o.Substring(0,$x)
        $prop = "Nessus_CLI_Status_" + $prop.Replace(" ","_")
        $value = $o.Substring($x+1,$o.Length-$x-1)
        $out2 += $prop + "=" + $value.trim() + ";"
    }
    $log_details = $out2.Substring(0,$out2.Length-1)
    log-event $log_file $log_process "Nessus Agent Status" $log_details
}
else
{
    "NessusCLI NotFound"
    $log_details = "Nessus_CLI_Status_Running=Not_Found"
}