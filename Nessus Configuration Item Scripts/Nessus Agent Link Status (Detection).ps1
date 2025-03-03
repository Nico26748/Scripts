# Taken from: MSB - Software - Nessus - Relink Agent with Bad Link or Bad Agent Name
# Nessus Agent - Display Status

if (Test-Path -Path "C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe")
{
    $scriptblock = {C:\Program` Files\Tenable\Nessus` Agent\nessuscli.exe agent status --show-uuid}
    $status = Invoke-Command -scriptblock $scriptblock

    $status_linkStatus = ($status | Where-Object { $_.StartsWith("Link status:") }).replace('Link status: ','')
	
    if ($status_linkStatus -notlike "Connected*")
    {
        $Compliance = $false
    }
    Else
    {
        $Compliance = $true
    }
}

Return $Compliance
