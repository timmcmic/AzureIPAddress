
<#PSScriptInfo

.VERSION 1.2

.GUID bc41499f-a9d2-4329-9110-d049984143c1

.AUTHOR timmcmic

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 This script allows scanning of azure ip address spaces for an azure ip. 

#> 
Param(
    [Parameter(Mandatory = $false)]
    [string]$IPAddressToTest="0.0.0.0",
    [Parameter(Mandatory = $true)]
    [string]$logFolderPath=$NULL
)

$ErrorActionPreference = 'Stop'

#-------------------------------------------------------------------------------

Function new-LogFile
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$logFileName,
        [Parameter(Mandatory = $true)]
        [string]$logFolderPath
    )

    [string]$logFileSuffix=".log"
    [string]$fileName=$logFileName+$logFileSuffix

    # Get our log file path

    $logFolderPath = $logFolderPath+"\"+$logFileName+"\"
    
    #Since $logFile is defined in the calling function - this sets the log file name for the entire script
    
    $global:LogFile = Join-path $logFolderPath $fileName

    #Test the path to see if this exists if not create.

    [boolean]$pathExists = Test-Path -Path $logFolderPath

    if ($pathExists -eq $false)
    {
        try 
        {
            #Path did not exist - Creating

            New-Item -Path $logFolderPath -Type Directory
        }
        catch 
        {
            throw $_
        } 
    }
}

#-------------------------------------------------------------------------------
Function Out-LogFile
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory = $true)]
        $String,
        [Parameter(Mandatory = $false)]
        [boolean]$isError=$FALSE
    )

    # Get the current date

    [string]$date = Get-Date -Format G

    # Build output string
    #In this case since I abuse the function to write data to screen and record it in log file
    #If the input is not a string type do not time it just throw it to the log.

    if ($string.gettype().name -eq "String")
    {
        [string]$logstring = ( "[" + $date + "] - " + $string)
    }
    else 
    {
        $logString = $String
    }

    # Write everything to our log file and the screen

    $logstring | Out-File -FilePath $global:LogFile -Append

    #Write to the screen the information passed to the log.

    if ($string.gettype().name -eq "String")
    {
        Write-Host $logString
    }
    else 
    {
        write-host $logString | select-object -expandProperty *
    }

    #If the output to the log is terminating exception - throw the same string.

    if ($isError -eq $TRUE)
    {
        #Ok - so here's the deal.
        #By default error action is continue.  IN all my function calls I use STOP for the most part.
        #In this case if we hit this error code - one of two things happen.
        #If the call is from another function that is not in a do while - the error is logged and we continue with exiting.
        #If the call is from a function in a do while - write-error rethrows the exception.  The exception is caught by the caller where a retry occurs.
        #This is how we end up logging an error then looping back around.

        write-error $logString

        #Now if we're not in a do while we end up here -> go ahead and create the status file this was not a retryable operation and is a hard failure.

        exit
    }
}

#-------------------------------------------------------------------------------
Function Test-PowershellVersion
    {
    [cmdletbinding()]

    $functionPowerShellVersion = $NULL

    Out-LogFile -string "********************************************************************************"
    Out-LogFile -string "BEGIN TEST-POWERSHELLVERSION"
    Out-LogFile -string "********************************************************************************"

    #Write function parameter information and variables to a log file.

    $functionPowerShellVersion = $PSVersionTable.PSVersion

    out-logfile -string "Determining powershell version."
    out-logfile -string ("Major: "+$functionPowerShellVersion.major)
    out-logfile -string ("Minor: "+$functionPowerShellVersion.minor)
    out-logfile -string ("Patch: "+$functionPowerShellVersion.patch)
    out-logfile -string $functionPowerShellVersion

    if ($functionPowerShellVersion.Major -ge 7)
    {
        out-logfile -string "Powershell 7 and higher is currently not supported due to module compatibility issues."
        out-logfile -string "Please run module from Powershell 5.x"
        out-logfile -string "" -isError:$true
    }
    else
    {
        out-logfile -string "Powershell version is not powershell 7.1 proceed."
    }

    Out-LogFile -string "********************************************************************************"
    Out-LogFile -string "END TEST-POWERSHELLVERSION"
    Out-LogFile -string "********************************************************************************"

}

#-------------------------------------------------------------------------------

function get-AzureHTMLData
{
    param(
        [Parameter(Mandatory = $true)]
        $azureCloudLocation
    )

    $functionHTMLData = $null

    out-logfile -string "Starting get-AzureHTMLData"

    try {
        out-logfile -string "Invoking web request to obtain html data."
        $functionHTMLData = invoke-webRequest -Uri $azureCloudLocation -errorAction Stop
        out-logfile -string "Web data successfully retrieved."
    }
    catch {
        out-logfile -string "Unable to obtain azure html data."
        out-logfile -string $_ -isError:$true
    }

    out-logFile -string "Ending get-AzureHTMLData"

    return $functionHTMLData
}

#-------------------------------------------------------------------------------

function get-AzureDownloadLink
{
    param(
        [Parameter(Mandatory = $true)]
        $azureCloudLocation
    )

    $functionDownloadLink = $NULL
    #$functionLinkString = "click here to download manually"
    $functionLinkString = "Download"

    out-logfile -string "Starting get-AzureDownloadLink"

    $functionDownloadLink = $azureCloudLocation.links | where-object {$_.InnerText -eq $functionLinkString}

    out-logfile -string $functionDownloadLink

    $functionDownLoadLink = $functionDownLoadLink.href

    out-logfile -string $functionDownLoadLink

    out-logfile -string "Ending get-AzureDownloadLink"

    return $functionDownloadLink
}

#-------------------------------------------------------------------------------
function get-AzureJSONData
{
    param(
        [Parameter(Mandatory = $true)]
        $azureCloudLocation
    )

    $functionAzureJSONData = $NULL

    out-logfile -string "Starting get-AzureJSONData"

    try
    {
        out-logfile -string "Invoking web request to obtain json data..."

        $functionAzureJSONData = invoke-webRequest -uri $azureCloudLocation -errorAction STOP

        out-logfile -string "Web request to obtain json data successful."
    }
    catch
    {
        out-logfile -string "Unable to invoke web request to obtain json data."
        out-logfile -string $_ -isError:$TRUE
    }

    out-logfile -string "Converting downloaded data to powershell json format."

    try
    {
        $functionAzureJsonData = convertFrom-Json $functionAzureJsonData -errorAction STOP
    }
    catch
    {
        out-logfile -string "Unable to convert data to json format."
        out-logfile -string $_ -isError:$TRUE
    }


    out-logfile -string "Ending get-AzureJSONData"

    return $functionAzureJsonData
}

#-------------------------------------------------------------------------------
function export-AzureJSONData
{
    param(
        [Parameter(Mandatory = $true)]
        $exportLocation,
        [Parameter(Mandatory = $true)]
        $jsonData
    )

    out-logfile -string "Starting export-AzureJSONData"

    try
    {
        $jsonData | export-clixml $exportLocation
    }
    catch
    {
        out-logfile -string "Unable to export the json data."
        out-logfile -string $_ -isError:$TRUE
    }

    out-logfile -string "Ending export-AzureJSONData"
}

#-------------------------------------------------------------------------------

#*******************************************************************************
#Begin main script function
#*******************************************************************************

#Define function specific variables.

[string]$logFileName = ""
[string]$staticLogFileName = "AzureIPAddress"
[string]$azureIPInformationPublicCloud = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
[string]$azureIPInformationGovernmentCloud = "https://www.microsoft.com/en-us/download/details.aspx?id=57063"
$azurePublicCloudHTMLData = $null
$azureGovernmentCloudHTMLData = $null
$azurePublicCloudDownloadLink = $null
$azureGovernmentCloudDownloadLink = $null
$azurePublicCloudJSONData = $NULL
$azureGovernmentCloudJSONData = $null
#Define the log file name

$logFileName = $staticLogFileName

new-logfile -logFileName $logFileName -logFolderPath $logFolderPath

$azurePublicJSONExport = $global:logFile.replace(".log","-Public.xml")
$azureGovernmentJSONExport = $global:logFile.replace(".log","-Government.xml")

out-logfile -string "*************************************************************"
out-logfile -string "Starting AzureIPAddress.ps1"
out-logfile -string "*************************************************************"

out-logfile -string "Testing Powershell Version - 5.x required..."

Test-PowershellVersion

out-logfile -string "Obtaining the azure html data."

$azurePublicCloudHTMLData = get-AzureHTMLData -azureCloudLocation $azureIPInformationPublicCloud
$azureGovernmentCloudHTMLData = get-azureHTMLData -azureCloudLocation $azureIPInformationGovernmentCloud

out-logfile -string "Obtaining data download link..."

$azurePublicCloudDownloadLink = get-AzureDownloadLink -azureCloudLocation $azurePublicCloudHTMLData
$azureGovernmentCloudDownloadLink = get-AzureDownloadLink -azureCloudLocation $azureGovernmentCloudHTMLData

out-logfile -string "Obtaining json data..."

$azurePublicCloudJSONData = get-azureJSONData -azureCloudLocation $azurePublicCloudDownloadLink
$azureGovernmentCloudJSONData = get-azureJSONData -azureCloudLocation $azureGovernmentCloudDownloadLink

out-logfile -string "Export the JSON data to the logging directory."

export-AzureJSONData -exportLocation $azurePublicJSONExport -jsonData $azurePublicCloudJSONData
export-AzureJSONData -exportLocation $azureGovernmentJSONExport -jsonData $azureGovernmentCloudJSONData

out-logfile -string "Gather Azure IP information completed - the xml files may now be utilized for analysis."