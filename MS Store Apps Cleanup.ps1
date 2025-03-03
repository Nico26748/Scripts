# Taken from: MSB - Software - MS Store Apps - Cleanup
# Remove specified MS Store apps equal to or lower than a specified version
# Does not check if there are any later versions installed for the specified MS Store app
# Specified version should be the most recent UNSUPPORTED/VULNERABLE version to remove along with any lower versions

Param (
    [Parameter(Mandatory=$true)]
    [string] $WhatIf = "1"
)

if ($WhatIf -notmatch "0|1")
{
    return "WhatIf parameter should be 0 or 1"
}

### begin logging component - log to a text file indexed by Splunk
$log_location = "<LOG_LOCATION_GOES_HERE>"
$log_name = "<LOG_NAME_GOES_HERE>.log"
$log_file = $log_location + "\" + $log_name

function log-event
{
    Param ( [String] $log_file, [String] $log_process, [String] $log_event, [String] $log_details = "", [String] $delim = ";", [String] $append = $true)
    if(-not (Test-Path $log_location)) { New-Item -Path $log_location -ItemType "directory" | out-null }
    $d = Get-Date -Format "MM/dd/yyy HH:mm:ss"
    $evt= $log_process + $delim + $d + $delim + $log_event + $delim + $log_details
    if ($append) { $evt | Out-File -Filepath $log_file -Append }
    else { $evt | Out-File -Filepath $log_file }
}
### end logging component


function less_than_equalto_vers
{
    # compare version info for $ref_vers and $query_vers
    # return 1 if $query_vers version is less than or equal to $ref_vers
    # return 0 in all other cases
    Param (
        [Parameter(Mandatory=$true)]
        [string] $ref_vers,  # the version to use as a reference
        [string] $query_vers  # the version to compare to the reference
    )
    $ret_val = 0

    if ($ref_vers -eq $query_vers) # if the full versions match then we are done
    {
        $ret_val = 1
    }
    else # otherwise check if query version < ref version
    {
        # first split ref and query version components by the "." character and put them into an array of elements
        $rv = $ref_vers.Split(".")
        $qv = $query_vers.Split(".")

        try
        {
            for($i = 0; $i -lt $rv.Length; $i++) # iterate through each of the reference version elements 
            {
                if($qv[$i] -ne $null) # check if a corresponding query version element exists
                {
                    if([int]$qv[$i] -lt [int]$rv[$i]) # check if a query version element is less than ref version element
                    {
                        $ret_val = 1 # if so then we are done
                        break
                    }
                    elseif([int]$qv[$i] -gt [int]$rv[$i]) # query version element is greater than ref version element so exit loop
                    {
                        break
                    }
                }
                else
                {
                    # number of query_vers elements less than number of ref_vers elements, so skip
                }
            }
        }
        catch
        {
            # unexpected result, so skip;
        }
    }

    return $ret_val
}

function cleanup-store-ver
{
    # given a 'KNOWN BAD' version of a particular MS Store app, remove it and all older versions of it
    Param(
        [string] $appx_app,
        [string] $appx_vers
    )

    if($appx_vers -ne "") { $appx_name_vers = $appx_app + "_" + $appx_vers } else { $appx_name_vers = $appx_app }
    $appx_app_wildcard = $appx_app + "*"
    $appx_name_vers_wildcard = $appx_name_vers + "*"
    $log_process = "MSStoreScript"
    $log_event = $appx_name_vers + "_Uninstall"

    # uninstall AppxProvisionedPackages available to be installed for each new user profile
    $app = Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like $appx_app_wildcard}
    if($app)
    {
        foreach ($a in $app)
        {
            $FoundPackageName = $a.PackageName
            $FoundPackageNameWildcard = $a.PackageName + "*"
            if (less_than_equalto_vers $appx_vers $a.Version)
            {

                if($WhatIf -eq "1")
                {
                    "WHATIF - $appx_app AppxPv is less than or equal to $appx_vers : " + $FoundPackageName
                }
                if($WhatIf -eq "1" -or $WhatIf -eq "0")
                {
                    try
                    {
                        # previously used command: Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -eq $FoundPackageName} | Remove-AppxProvisionedPackage -Online -AllUsers
                        if($WhatIf -eq "1") {
                            "# WHATIF CMD: Remove-AppxProvisionedPackage $FoundPackageName -Online -AllUsers"
                        } else {
                            Remove-AppxProvisionedPackage $FoundPackageName -Online -AllUsers
                        }
                        $log_details = "AppxPv " + $FoundPackageName + " Uninstalled"
                    }
                    catch {
                        if ($Error[0] = "The system cannot find the path specified.") 
                        {
                            # directory already removed but reg key remains
                            $reg_key = "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications\" + $FoundPackageName
                            try
                            {
                                if($WhatIf -eq "1") {
                                    "# WHATIF CMD: remove-Item -Path $reg_key -Recurse"
                                } else {
                                    remove-Item -Path $reg_key -Recurse
                                }
                                $log_details = "AppxPv " + $FoundPackageName + " registry Removed : " + $reg_key
                            }
                            catch
                            {
                                $log_details = "Error removing AppxPv registry " + $FoundPackageName + " :" +  $reg_key + " : "  + $Error[0]
                            }
                        }
                        else 
                        {
                            # something else is causing an error
                            $log_details = "Error uninstalling AppxPv " + $FoundPackageName + " : " + $Error[0]
                        }
                    }
                    if ($log_details -ne $null)
                    {
                        $log_details    
                        if($WhatIf -ne "1") { log-event $log_file $log_process $log_event $log_details } # comment out this line to skip text file logging
                    }
                    $log_details = $null  # reset logging information 
                }
            }
            else
            {
                # "$appx_app AppxPv is greater than $appx_vers : " + $a.PackageName
            }
        }
    }
    else
    {
        # $appx_name_vers + " AppxPv Not installed"
    }


    # Uninstall AppxPackages actually installed for one or more user profiles
    $app = Get-AppxPackage -allusers | Where-Object {$_.PackageFullName -like $appx_app_wildcard}
    # "checking $appx_app_wildcard"
    if ($app)
    {
        foreach ($a in $app)
        {
            $FoundPackageFullName = $a.PackageFullName
            $FoundPackageFullNameWildcard = $a.PackageFullName + "*"
            #"found $FoundPackageFullName"
            if (less_than_equalto_vers $appx_vers $a.Version)
            {
                if($WhatIf -eq "1")
                {
                    "WHATIF - $appx_app Appx is less than or equal to $appx_vers and will be uninstalled : " + $FoundPackageFullName
                }
                if($WhatIf -eq "1" -or $WhatIf -eq "0")
                {
                    try {
                        # previously used command: Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq $FoundPackageFullName} | Remove-AppxPackage -AllUsers
                        # previously used command: Remove-AppxPackage $FoundPackageFullName -AllUsers

                        $RemoveApps = Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq $FoundPackageFullName}
                        foreach($RemoveApp in $RemoveApps)
                        {   
                            try
                            {
                                $FoundPackageFullName2 = $RemoveApp.PackageFullName
                                $PackageUserInformation = $RemoveApp.PackageUserInformation
                                "Removing $FoundPackageFullName2 :: $PackageUserInformation"
                                if($WhatIf -eq "1") {
                                    "# WHATIF CMD: Remove-AppxPackage -package $FoundPackageFullName2 -AllUsers -ErrorAction SilentlyContinue"
                                } else {
                                    Remove-AppxPackage -package $FoundPackageFullName2 -AllUsers -ErrorAction SilentlyContinue
                                }
                                $log_details = "Appx " + $FoundPackageFullName + " Uninstalled"
                            }
                            catch {
                                $log_details = "Error uninstalling Appx " + $FoundPackageFullName + " : " + $Error[0]
                            }
                        }
                        $log_details
                        $log_details = $null  # reset logging information 
                    }
                    catch {
                        $log_details = "Error finding or uninstalling Appx " + $FoundPackageFullName + " : " + $Error[0]
                    }

                    if ($log_details -ne $null)
                    {
                        $log_details    
                        if($WhatIf -ne "1") { log-event $log_file $log_process $log_event $log_details }  # comment out this line to skip text file logging
                    }
                    $log_details = $null  # reset logging information 

                    try {
                        ### Some Nessus false positive results are based on orphaned registry keys -- check if any exist and delete them if found
                        $reg_key = "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
                        $keys = Get-ChildItem -Path $reg_key | where-object {$_.Name -like ($reg_key.replace("HKLM:","HKEY_LOCAL_MACHINE\") + "\S-*")}
                        foreach ($k in $keys)
                        {
                            $skeys = Get-ChildItem -Path ($k.Name.Replace("HKEY_LOCAL_MACHINE\","HKLM:")) | where-object {$_.Name -like ($k.Name + "\" + $FoundPackageFullNameWildcard)}
                            foreach ($sk in $skeys)
                            {
                                $keyPath = $sk.Name.Replace("HKEY_LOCAL_MACHINE\","HKLM:")
                                if($WhatIf -eq "1") {
                                    "# WHATIF CMD: remove-Item -Path ($keyPath) -Recurse"
                                } else { 
                                    remove-Item -Path ($keyPath) -Recurse
                                }
                                $log_details = "Appx $FoundPackageFullName registry Removed : $keyPath"
                            }
                        }
                    }
                    catch {
                        $log_details = "Error removing registry key for Appx " + $FoundPackageFullName + " : " + $Error[0]
                    }

                    if ($log_details -ne $null)
                    {
                        $log_details    
                        if($WhatIf -ne "1") { log-event $log_file $log_process $log_event $log_details } # comment out this line to skip text file logging
                    }
                    $log_details = $null  # reset logging information 
                }
            }
            else
            {
                #"$appx_app Appx is greater than $appx_vers : $PackageFullName"
            }
        }
    }
    else
    {
        #$appx_name_vers + " Appx Not installed"
    }


    ### Some Nessus false positive results are based on orphaned directories -- check if any exist and delete them if found
    $progdir = "C:\Program Files\WindowsApps\" + $appx_name_vers_wildcard
    if (Test-Path -Path $progdir)
    {
        if($WhatIf -eq "1")
        {
            "WHATIF - $appx_app Remove orphaned directory : $progdir"
        }
        if($WhatIf -eq "1" -or $WhatIf -eq "0")
        {
            try
            {
                if($WhatIf -eq "1") {
                    "# WHATIF CMD: Remove-Item -Path $progdir -Force -Recurse -Confirm:$false"
                } else {
                    Remove-Item -Path $progdir -Force -Recurse -Confirm:$false
                }
                $log_details = "Removed directory $progdir"
            }
            catch
            {
                $log_details = "Error removing directory $progdir : " + $error[0]
            }
            if ($log_details -ne $null)
            {
                $log_details    
                if($WhatIf -ne "1") { log-event $log_file $log_process $log_event $log_details } # comment out this line to skip text file logging
            }
        }
    }
    else
    {
        # no orphaned directory found
    }
}


#### list most recent KNOWN BAD versions of apps - these versions and older versions will be removed
cleanup-store-ver "Microsoft.3DBuilder" "20.0.3.0"
cleanup-store-ver "Microsoft.AV1VideoExtension" "1.1.40831.0"
cleanup-store-ver "Microsoft.HEIFImageExtension" "1.0.40978.0"
cleanup-store-ver "Microsoft.HEVCVideoExtension" "1.0.50361.0"
cleanup-store-ver "Microsoft.MPEG2VideoExtension" "1.0.22661.0"
cleanup-store-ver "Microsoft.MSPaint" "6.2203.1037.0"
cleanup-store-ver "Microsoft.Office.OneNote" "16001.14326.21146.0"
cleanup-store-ver "Microsoft.OutlookForWindows" "1.0.0.0"
cleanup-store-ver "Microsoft.Print3D" "9999.0"
cleanup-store-ver "Microsoft.Microsoft3DViewer" "7.2211.24012.0"
cleanup-store-ver "Microsoft.RawImageExtensionr" "2.1.30391.0"
#cleanup-store-ver "Microsoft.MicrosoftOfficeHub" "18.2106.12410.0"
cleanup-store-ver "Microsoft.VP9VideoExtensions" "11.0.22681.0"
cleanup-store-ver "Microsoft.WindowsTerminal" "1.12.10983.0"
cleanup-store-ver "Microsoft.OutlookForWindows" "1.0.0.0"
cleanup-store-ver "MSTeams" "1.0.0.0"
cleanup-store-ver "Microsoft.WebpImageExtension" "1.0.22753.0"
cleanup-store-ver "Microsoft.WebMediaExtensions" "1.0.20875.0"
cleanup-store-ver "Microsoft.RemoteDesktop" "10.2.3000.0"
cleanup-store-ver "Microsoft.MicrosoftOfficeHub" "18.2412.1105.0"

"Done"