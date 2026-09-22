#requires -Version 3
$currentLocation = if($PSScriptRoot){ $PSScriptRoot } else { (Get-Location).Path }
Write-Host $currentLocation
Set-Location $currentLocation

#region Add Assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, WindowsFormsIntegration
$code = @"
using System;
using System.Runtime.InteropServices;

namespace System
{
	public class IconExtractor
	{

	 public static IntPtr Extract(string file, int number, bool largeIcon)
	 {
	  IntPtr large;
	  IntPtr small;
	  ExtractIconEx(file, number, out large, out small, 1);
	  return largeIcon ? large : small;

	 }
	 [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
	 private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

	 [DllImport("user32.dll", SetLastError = true)]
	 public static extern bool DestroyIcon(IntPtr hIcon);

	}
}
"@
Add-Type -TypeDefinition $code



# Mahapps Library
$mahAppsPath1 = Join-Path $env:ProgramFiles "SMSAgent\ConfigMgr Task Sequence Monitor\MahApps.Metro.dll"
$interactivityPath1 = Join-Path $env:ProgramFiles "SMSAgent\ConfigMgr Task Sequence Monitor\System.Windows.Interactivity.dll"

if (Test-Path -Path $mahAppsPath1)
{
    [System.Reflection.Assembly]::LoadFrom($mahAppsPath1) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($interactivityPath1) | Out-Null
}

$programFilesX86 = ${env:ProgramFiles(x86)}
if ($programFilesX86) {
    $mahAppsPath2 = Join-Path $programFilesX86 "SMSAgent\ConfigMgr Task Sequence Monitor\MahApps.Metro.dll"
    $interactivityPath2 = Join-Path $programFilesX86 "SMSAgent\ConfigMgr Task Sequence Monitor\System.Windows.Interactivity.dll"
    if (Test-Path -Path $mahAppsPath2)
    {
        [System.Reflection.Assembly]::LoadFrom($mahAppsPath2) | Out-Null
        [System.Reflection.Assembly]::LoadFrom($interactivityPath2) | Out-Null
    }
}

$mahAppsPathLocal = Join-Path $currentLocation "MahApps.Metro.dll"
$interactivityPathLocal = Join-Path $currentLocation "System.Windows.Interactivity.dll"
if (Test-Path -Path $mahAppsPathLocal)
{
    [System.Reflection.Assembly]::LoadFrom($mahAppsPathLocal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($interactivityPathLocal) | Out-Null
}

#endregion

#region Constants
# ConfigMgr Status Message ID for skipped/disabled task sequence steps
$script:SkippedStepStatusMsgID = '11128'

# Fallback sentinel value when exit code filtering is disabled
$script:NoExitCodeFilterSentinel = '999999999999999999999999'
#endregion

#region GUI and Variables
### Main Window ###
# GUI
$mainWindowXamlPath = Join-Path $currentLocation "XAML\MainWindow.xaml"
[xml]$xaml = Get-Content $mainWindowXamlPath

$BuildExtVersionSql = @()
$buildExtCsvPath = Join-Path $currentLocation "BuildExt.csv"
if (Test-Path $buildExtCsvPath) {
    Import-Csv -Path $buildExtCsvPath -Delimiter ";" -Header Build, Version | ForEach-Object {
        $buildEscaped = $_.Build -replace "'", "''"
        $versionEscaped = $_.Version -replace "'", "''"
        if (-not [string]::IsNullOrWhiteSpace($buildEscaped)) {
            $BuildExtVersionSql += "WHEN sys.BuildExt like '$buildEscaped' THEN '$versionEscaped'"
        }
    }
}

$hash = [hashtable]::Synchronized(@{})
$reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml)
$hash.Window = [Windows.Markup.XamlReader]::Load( $reader )
$script:PSInstances = @()
$script:LogPath = Join-Path $env:TEMP 'ConfigMgrTSMonitor.log'
$Global:Timezones = @()
$hash.Results = @()

function Write-TSMonitorLog
{
    param([string]$Message)
    try
    {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        [System.IO.File]::AppendAllText($script:LogPath, "[$timestamp] $Message`r`n")
    }
    catch { }
}

Write-TSMonitorLog 'Application started.'

$hash.TaskSequence = $hash.Window.FindName('TaskSequence')
$hash.TimePeriod = $hash.Window.FindName('TimePeriod')
$hash.ErrorsOnly = $hash.Window.FindName('ErrorsOnly')
$hash.SuccessCode = $hash.Window.FindName('SuccessCode')
$hash.DisabledSteps = $hash.Window.FindName('DisabledSteps')
$hash.SkippedSteps = $hash.Window.FindName('SkippedSteps')
$hash.ComputerName = $hash.Window.FindName('ComputerName')
$hash.DeviceCount = $hash.Window.FindName('DeviceCount')
$hash.BuildExt = $hash.Window.FindName('BuildExt')
$hash.ActionName = $hash.Window.FindName('ActionName')
$hash.RefreshPeriod = $hash.Window.FindName('RefreshPeriod')
$hash.RefreshNow = $hash.Window.FindName('RefreshNow')
$hash.DataGrid = $hash.Window.FindName('DataGrid')
$hash.ActionOutput = $hash.Window.FindName('ActionOutput')
$hash.SettingsButton = $hash.Window.FindName('SettingsButton')
$hash.ReportButton = $hash.Window.FindName('ReportButton')
$hash.ErrorCount = $hash.Window.FindName('ErrorCount')

$hash.Window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)
    $exception = $eventArgs.Exception
    Write-TSMonitorLog "Unhandled UI exception: $($exception.ToString())"
    $eventArgs.Handled = $true
    if ($hash.ActionOutput)
    {
        $hash.ActionOutput.Text = "[ERROR] The UI encountered an unexpected error. See $script:LogPath"
    }
})

$gridIco1 = Join-Path $env:ProgramFiles "SMSAgent\ConfigMgr Task Sequence Monitor\Grid.ico"
if (Test-Path -Path $gridIco1)
{
    $hash.Window.Icon = $gridIco1
}
if ($programFilesX86) {
    $gridIco2 = Join-Path $programFilesX86 "SMSAgent\ConfigMgr Task Sequence Monitor\Grid.ico"
    if (Test-Path -Path $gridIco2)
    {
        $hash.Window.Icon = $gridIco2
    }
}
$gridIcoLocal = Join-Path $currentLocation "Grid.ico"
if (Test-Path -Path $gridIcoLocal)
{
	$hash.Window.add_Loaded({
		$hash.Window.Icon = $gridIcoLocal
	})
}

### Settings Window ###
$configXamlPath = Join-Path $currentLocation "XAML\Config.xaml"
[xml]$xaml2 = Get-Content $configXamlPath

$reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml2)
$hash.Window2 = [Windows.Markup.XamlReader]::Load( $reader )
$hash.SQLServer = $hash.Window2.FindName('SQLServer')
$hash.Database = $hash.Window2.FindName('Database')
$hash.ConnectSQL = $hash.Window2.FindName('ConnectSQL')
$hash.TSList = $hash.Window2.FindName('TSList')
$hash.StartDate = $hash.Window2.FindName('StartDate')
$hash.EndDate = $hash.Window2.FindName('EndDate')
$hash.GenerateReport = $hash.Window2.FindName('GenerateReport')
$hash.SettingsTab = $hash.Window2.FindName('SettingsTab')
$hash.ReportTab = $hash.Window2.FindName('ReportTab')
$hash.Tabs = $hash.Window2.FindName('Tabs')
$hash.Working = $hash.Window2.FindName('Working')
$hash.Runasadmin = $hash.Window2.FindName('Runasadmin')
$hash.ReportProgress = $hash.Window2.FindName('ReportProgress')
$hash.Link1 = $hash.Window2.FindName('Link1')
$hash.Link2 = $hash.Window2.FindName('Link2')
$hash.DTFormat = $hash.Window2.FindName('DTFormat')
$hash.GreyDisabledSteps = $hash.Window2.FindName('GreyDisabledSteps')

if (Test-Path -Path $gridIco1)
{
    $hash.Window2.ShowInTaskbar = $true
}
if ($programFilesX86 -and (Test-Path -Path $gridIco2))
{
    $hash.Window2.ShowInTaskbar = $true
}
if (Test-Path -Path $gridIcoLocal)
{
    $hash.Window2.ShowInTaskbar = $true
}

$script:SQLServer = $hash.SQLServer.Text
$Script:Database = $hash.Database.Text
#endregion

#region Icons and Runspacepool
# Output SystemIcons to bmps
$icons = @()
$global:greentickiconpath = Join-Path $env:temp "GreenTick.bmp"
$icons += $greentickiconpath 
$global:redcrossiconpath = Join-Path $env:temp "RedCross.bmp"
$icons += $redcrossiconpath

function Save-ExtractedIconBitmap {
    param (
        [string]$SourceFile,
        [int]$IconIndex,
        [string]$DestinationPath
    )

    $iconHandle = [System.IconExtractor]::Extract($SourceFile, $IconIndex, $true)
    if ($iconHandle -eq [IntPtr]::Zero) {
        throw "Could not extract icon index $IconIndex from $SourceFile."
    }

    try {
        $source = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $iconHandle,
            [System.Windows.Int32Rect]::Empty,
            [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
        )
        $encoder = New-Object System.Windows.Media.Imaging.BmpBitmapEncoder
        $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($source))
        $stream = [System.IO.File]::Create($DestinationPath)
        try {
            $encoder.Save($stream)
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        [System.IconExtractor]::DestroyIcon($iconHandle) | Out-Null
    }
}

if (!(Test-Path $greentickiconpath))
{
    Save-ExtractedIconBitmap -SourceFile 'comres.dll' -IconIndex 8 -DestinationPath $greentickiconpath
}
if (!(Test-Path $redcrossiconpath))
{
    Save-ExtractedIconBitmap -SourceFile 'comres.dll' -IconIndex 10 -DestinationPath $redcrossiconpath
}

$script:RunspacePool = [runspacefactory]::CreateRunspacePool()
$RunspacePool.ApartmentState = 'STA'
$RunspacePool.ThreadOptions = 'ReUseThread'
$RunspacePool.Open()
#endregion

#region Functions

Function Get-FilterParams 
{
    param (
        $ErrorsOnly,
        $SuccessCode,
        $DisabledSteps
    )

    $isErrorsOnly = ($ErrorsOnly -eq 'True' -or $ErrorsOnly -eq $true)
    $isDisabledSteps = ($DisabledSteps -eq 'True' -or $DisabledSteps -eq $true)

    $ExitCode = if ($isErrorsOnly) { $SuccessCode } else { $script:NoExitCodeFilterSentinel }
    $DisabledStep = if ($isDisabledSteps) { "''" } else { $script:SkippedStepStatusMsgID }

    $ExitCodeSanitized = if ($ExitCode -eq $script:NoExitCodeFilterSentinel) { "999999999" } else { ($ExitCode -replace '[^0-9,-]', '') }
    if ([string]::IsNullOrWhiteSpace($ExitCodeSanitized)) { $ExitCodeSanitized = "999999999" }

    $DisabledStepSanitized = if ($DisabledStep -eq "''") { "''" } else { ($DisabledStep -replace '[^0-9,-]', '') }
    if ([string]::IsNullOrWhiteSpace($DisabledStepSanitized)) { $DisabledStepSanitized = "''" }

    return @{
        ExitCodeSanitized     = $ExitCodeSanitized
        DisabledStepSanitized = $DisabledStepSanitized
    }
}

Function Get-DateTimeFormat 
{
    $isDaylight = [System.TimeZoneInfo]::Local.IsDaylightSavingTime((Get-Date))
    if ($isDaylight)
    {
        $TimeZone = [System.TimeZoneInfo]::Local.DaylightName
    }
    Else 
    {
        $TimeZone = [System.TimeZoneInfo]::Local.StandardName
    }

    $Global:Timezones = @(
        [pscustomobject]@{ TimeZone = 'UTC' },
        [pscustomobject]@{ TimeZone = $TimeZone }
    )
}

Function Get-TaskSequenceList 
{
    param ($hash,$RunspacePool)

    $code =
    {
        param($hash,$SQLServer,$Database)

        # If SQLinstance not populated, ask for connection
        if ($SQLServer -eq '<SQLServer\Instance>' -or [string]::IsNullOrWhiteSpace($SQLServer))
        {
            $hash.Window.Dispatcher.Invoke([action]{
                $hash.ActionOutput.Text = 'No SQL Server defined. Click Settings, and set the SQL Server and Database.'
            })
            return
        }

        $hash.Window.Dispatcher.Invoke([action]{
            $hash.ActionOutput.Text = 'Connecting to SQL Server...'
        })

        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        try
        {
            $connectionString = "Server=$SQLServer;Database=$Database;Integrated Security=SSPI;Connect Timeout=5;"
            $connection.ConnectionString = $connectionString
            $connection.Open()

            $Query = "
                SELECT DISTINCT v_TaskSequencePackage.Name AS 'Task Sequence' FROM v_TaskSequencePackage
                INNER JOIN v_Program ON v_Program.PackageID = v_TaskSequencePackage.PackageID
                WHERE (0x00001000 & dbo.v_Program.ProgramFlags)/0x00001000 != 1
                ORDER BY v_TaskSequencePackage.Name
            "
            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $result = $command.ExecuteReader()
            $table = New-Object -TypeName 'System.Data.DataTable'
            $table.Load($result)
            $result.Dispose()
            $command.Dispose()

            # Load data into list shared with the UI runspace
            $taskSequences = foreach ($Row in $table.Rows)
            {
                $Row.'Task Sequence'
            }

            # Output to Task Sequence combobox
            $hash.Window.Dispatcher.Invoke([action]{
                $hash.TaskSequences = [Array]$taskSequences
                $hash.TaskSequence.ItemsSource = $hash.TaskSequences
                if ($hash.TSList)
                {
                    $hash.TSList.ItemsSource = $hash.TaskSequences
                }
                $hash.ActionOutput.Text = 'Connected to SQL Server database. Select a Task Sequence.'
            })
        }
        catch 
        {
            $MyError = $_.Exception.Message
            $hash.Window.Dispatcher.Invoke([action]{
                $hash.ActionOutput.Text = "[ERROR] Could not connect to SQL Server: $MyError"
            })
        }
        finally
        {
            if ($connection -and $connection.State -ne [System.Data.ConnectionState]::Closed)
            {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    # Read values from UI on the calling thread before handing off to runspace
    $SQLServer = $hash.SQLServer.Text
    $Database  = $hash.Database.Text

    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database)
    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Get-TaskSequenceData 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$BuildExtVersionSql,$TimePeriod,$SuccessCode,$ExitCodeSanitized,$DisabledStepSanitized,$SkippedSteps,$GreyDisabledSteps,$ComputerName,$ActionName,$TS,$DTFormat)

        # Notify of data retrieval         
        $hash.Window.Dispatcher.Invoke(
            [action]{
                $hash.ActionOutput.Text = 'Retrieving data...'
                $hash.DataGrid.ItemsSource = ''
        })

        $SuccessCodeSanitized = ($SuccessCode -replace '[^0-9,-]', '')
        if ([string]::IsNullOrWhiteSpace($SuccessCodeSanitized)) { $SuccessCodeSanitized = "999999999" }
        
        $compDisplayName = if ($ComputerName -is [System.Management.Automation.PSCustomObject]) { $ComputerName.DisplayName } else { $ComputerName }
        $compValue = if ($ComputerName -is [System.Management.Automation.PSCustomObject]) { $ComputerName.Value } else { $ComputerName }

        if ($compDisplayName -eq '-All-' -or [string]::IsNullOrEmpty($compDisplayName))
        {
            $SQLComputerName = '%'
        }
        Else 
        {
            $SQLComputerName = $compValue
			$hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ActionOutput.Text = "Search for device: $compDisplayName - $compValue"
            })
        }
		
		if ($ActionName -eq '-All-' -or [string]::IsNullOrEmpty($ActionName))
        {
            $SQLActionName = '%'
        }
        Else 
        {
            $SQLActionName = $ActionName
        }
        
        $greentickiconpath = Join-Path $env:temp "GreenTick.bmp"
        $redcrossiconpath = Join-Path $env:temp "RedCross.bmp"
        $greenTickIconPath = ([System.Uri]$greentickiconpath).AbsoluteUri
        $redCrossIconPath = ([System.Uri]$redcrossiconpath).AbsoluteUri
        
        # Connect to SQL server
        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        try
        {
            $connectionString = "Server=$SQLServer;Database=$Database;Integrated Security=SSPI;Connect Timeout=5;"
            $connection.ConnectionString = $connectionString
            $connection.Open()

            if ($SQLComputerName -eq '%') {
                $specificCondition = "and sys.Name0 like @SQLComputerName"
            } else {
                $specificCondition = "and sys.SMBIOS_GUID0 = @SQLComputerName"
            }
            
            $baseQuery = "
                Select Distinct sys.Name0 as 'Computer Name',
                sys.SMBIOS_GUID0 as 'GUID',
                tsp.Name as 'Task Sequence',
                comp.UserName0,
                CASE
                    WHEN cmcbs.CNIsOnInternet = 0 THEN 'Intranet'
                    WHEN cmcbs.CNIsOnInternet = 1 THEN 'Internet'
                    ELSE CAST(cmcbs.CNIsOnInternet AS varchar)
                END as [Connection Type], 
                CAST(
                     CASE
                          $($BuildExtVersionSql -join "`n")
                          ELSE sys.BuildExt
                     END AS char) as BuildExt, 
                comp.Model0,
                BIOS.SMBIOSBIOSVersion0 as BIOSVersion,
                ExecutionTime,
                Step,
                tes.ActionName,
                GroupName,
                tes.LastStatusMsgName,
                tes.LastStatusMsgID,
                ExitCode,
                ActionOutput
                from vSMS_TaskSequenceExecutionStatus tes
                INNER JOIN v_R_System sys on tes.ResourceID = sys.ResourceID
                INNER JOIN (select MachineID, Name, CNIsOnInternet, LastPolicyRequest, LastDDR as [Last Heartbeat],
                   LastHardwareScan, max(CNLastOnlinetime) as [Last Online Time]
                   FROM v_CollectionMemberClientBaselineStatus
                   GROUP BY Name, MachineID, CNIsOnInternet, ClientVersion, LastPolicyRequest, LastDDR,
                   LastHardwareScan, CNLastOnlinetime) cmcbs ON cmcbs.MachineID = sys.ResourceID
                LEFT JOIN v_GS_COMPUTER_SYSTEM comp ON comp.ResourceID = sys.ResourceID
                LEFT JOIN v_GS_PC_BIOS BIOS ON BIOS.ResourceID = sys.ResourceID
                LEFT JOIN v_RA_System_MACAddresses mac on tes.ResourceID = mac.ResourceID
                INNER JOIN v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                where tsp.Name = @TS
                and DATEDIFF(hour, (CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, ExecutionTime), DATENAME(TzOffset, SYSDATETIMEOFFSET())))), GETDATE()) <= @TimePeriod
                and ActionName like @SQLActionName
                and ExitCode not in ($ExitCodeSanitized)
                and tes.LastStatusMsgID not in ($DisabledStepSanitized)
            "

            $Query = "$baseQuery $specificCondition ORDER BY ExecutionTime Desc"
            
            $ErrQuery = "
                Select Count(Name0) as 'Count' from (Select DISTINCT (Name0), ActionName, ExecutionTime 
                from vSMS_TaskSequenceExecutionStatus tes
                inner join v_R_System sys on tes.ResourceID = sys.ResourceID
                left join v_RA_System_MACAddresses mac on tes.ResourceID = mac.ResourceID
                inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                where tsp.Name = @TS
                and DATEDIFF(hour,(CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, ExecutionTime), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) ),GETDATE()) <= @TimePeriod
                and ActionName like @SQLActionName
                and ExitCode not in ($SuccessCodeSanitized) $specificCondition) as t
            "

            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $command.Parameters.AddWithValue("@TimePeriod", [int]$TimePeriod) | Out-Null
            $command.Parameters.AddWithValue("@SQLActionName", [string]$SQLActionName) | Out-Null
            $command.Parameters.AddWithValue("@SQLComputerName", [string]$SQLComputerName) | Out-Null
            $result = $command.ExecuteReader()
            $table = New-Object -TypeName 'System.Data.DataTable'
            $table.Load($result)
            $result.Dispose()
            $command.Dispose()

            $commandErr = $connection.CreateCommand()
            $commandErr.CommandText = $ErrQuery
            $commandErr.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $commandErr.Parameters.AddWithValue("@TimePeriod", [int]$TimePeriod) | Out-Null
            $commandErr.Parameters.AddWithValue("@SQLActionName", [string]$SQLActionName) | Out-Null
            $commandErr.Parameters.AddWithValue("@SQLComputerName", [string]$SQLComputerName) | Out-Null
            $erresult = $commandErr.ExecuteReader()
            $errtable = New-Object -TypeName 'System.Data.DataTable'
            $errtable.Load($erresult)
            $erresult.Dispose()
            $commandErr.Dispose()

            if ($table.Rows.Count -lt 1)
            {
                $hash.Window.Dispatcher.Invoke(
                    [action]{
                        $hash.ActionOutput.Text = 'No results.'
                })
                return
            }

            # Gather results into psobject list
            $successCodeList = @($SuccessCode.Replace(" ", "").Split(",") | Where-Object { $_ -ne "" })
            $i = 0
            $ResultsList = foreach ($Row in $table.Rows)
            {
                $i++
                $isSuccess = ($Row.ExitCode.ToString() -in $successCodeList)
                $iconPath = if ($isSuccess) { $greenTickIconPath } else { $redCrossIconPath }

                $exTime = if ($DTFormat -eq 'UTC') { $Row.'ExecutionTime' } else { [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$Row.'ExecutionTime', [System.TimeZoneInfo]::Local) }

                $isSkipped = ([string]$Row.LastStatusMsgID -eq $script:SkippedStepStatusMsgID -or $Row.LastStatusMsgName -like '*skipped*')
                $isGreyed = if ($GreyDisabledSteps -eq 'True' -or $GreyDisabledSteps -eq $true) { $isSkipped } else { $false }

                [pscustomobject]@{
                    IconPath           = $iconPath
                    ComputerName       = $Row.'Computer Name'
                    GUID               = $Row.'GUID'
                    'Connection Type'  = $Row.'Connection Type'
                    BuildExt           = $Row.'BuildExt'
                    Model0             = $Row.'Model0'
                    BIOSVersion        = $Row.'BIOSVersion'
                    ExecutionTime      = $exTime
                    Step               = $Row.'Step'
                    ActionName         = $Row.'ActionName'
                    GroupName          = $Row.'GroupName'
                    LastStatusMsgName  = $Row.'LastStatusMsgName'
                    ExitCode           = $Row.'ExitCode'
                    ActionOutput       = $Row.'ActionOutput'
                    Record             = $i
                    IsSkipped          = $isSkipped
                    IsGreyed           = $isGreyed
                }
            }

            $hash.Results = [Array]$ResultsList

            $displayResults = $hash.Results
            if ($displayResults.Count -eq 1)
            {
                $Row = $table.Rows[0]
                $isSuccess = ($Row.ExitCode.ToString() -in $successCodeList)
                $iconPath = if ($isSuccess) { $greenTickIconPath } else { $redCrossIconPath }

                $dummyObj = [pscustomobject]@{
                    IconPath           = $iconPath
                    ComputerName       = ' '
                    GUID               = ' '
                    'Connection Type'  = ' '
                    BuildExt           = ' '
                    Model0             = ' '
                    BIOSVersion        = ' '
                    ExecutionTime      = ' '
                    Step               = ' '
                    ActionName         = ' '
                    GroupName          = ' '
                    LastStatusMsgName  = ' '
                    ExitCode           = ' '
                    ActionOutput       = ' '
                    Record             = 999999
                    IsSkipped          = $false
                    IsGreyed           = $false
                }
                $displayResults = [Array]($displayResults + $dummyObj)
            }

            $FilteredResults = if ($SkippedSteps -eq 'False' -or $SkippedSteps -eq $false) {
                [Array]($displayResults | Where-Object { -not $_.IsSkipped })
            } else {
                $displayResults
            }
            $FilteredResults = [Array]($FilteredResults | Select-Object -Property IconPath, ComputerName, GUID, 'Connection Type', BuildExt, Model0, BIOSVersion, ExecutionTime, Step, ActionName, GroupName, LastStatusMsgName, ExitCode, Record, IsSkipped, IsGreyed)

            $errCount = if ($errtable -and $errtable.Rows.Count -gt 0) { $errtable.Rows[0]['Count'] } else { 0 }
            
            # Display results in datagrid         
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.DataGrid.ItemsSource = $FilteredResults
                    $hash.ErrorCount.Text = $errCount
                    $hash.ActionOutput.Text = 'Click any step to see the action output.'
            })
        }
        catch 
        {
            $MyError = $_.Exception.Message
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ActionOutput.Text = "[ERROR] Could not connect to SQL Server database! $MyError"
            })
            return
        }
        finally
        {
            if ($connection -and $connection.State -ne [System.Data.ConnectionState]::Closed)
            {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    # Set variables from Hash table
    $SQLServer = $hash.SQLServer.Text
    $Database = $hash.Database.Text
    $TimePeriod = $hash.TimePeriod.Text
	$SuccessCode = $hash.SuccessCode.Text
    $ErrorsOnly = $hash.ErrorsOnly.IsChecked
	$DisabledSteps = $hash.DisabledSteps.IsChecked
    $SkippedSteps = $hash.SkippedSteps.IsChecked
    $GreyDisabledSteps = if ($null -ne $Global:GreyDisabledSteps) { $Global:GreyDisabledSteps } else { $true }
    $ComputerName = $hash.ComputerName.SelectedItem
	$ActionName = $hash.ActionName.SelectedItem
    $TS = $hash.TaskSequence.SelectedItem
    $DTFormat = $hash.DTFormat.SelectedItem

    $filterParams = Get-FilterParams -ErrorsOnly $ErrorsOnly -SuccessCode $SuccessCode -DisabledSteps $DisabledSteps
    $ExitCodeSanitized = $filterParams.ExitCodeSanitized
    $DisabledStepSanitized = $filterParams.DisabledStepSanitized

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($BuildExtVersionSql).AddArgument($TimePeriod).AddArgument($SuccessCode).AddArgument($ExitCodeSanitized).AddArgument($DisabledStepSanitized).AddArgument($SkippedSteps).AddArgument($GreyDisabledSteps).AddArgument($ComputerName).AddArgument($ActionName).AddArgument($TS).AddArgument($DTFormat)

    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ActionOutput 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$Record)
        $msg = $hash.Results | Where-Object { $_.Record -eq $Record } | Select-Object -First 1
        if ($msg) {
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ActionOutput.Text = $msg.ActionOutput
            })
        }
    }

    # Set variables from Hash table. SelectionChanged also fires when the grid
    # is cleared, so there may be no selected item.
    $selectedItem = $hash.DataGrid.SelectedItem
    if ($null -eq $selectedItem) { return }
    $Record = $selectedItem.Record

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($Record)
    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ComputerNames 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$BuildExtVersionSql,$TimePeriod,$ExitCodeSanitized,$DisabledStepSanitized,$TS)

        # Connect to SQL Server
        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        try
        {
            $connectionString = "Server=$SQLServer;Database=$Database;Integrated Security=SSPI;Connect Timeout=5;"
            $connection.ConnectionString = $connectionString
            $connection.Open()

            # Run SQL query
            $Query = "
                Select Distinct Name0,
                SMBIOS_GUID0 as 'GUID',
                CAST(
                    CASE
                      $($BuildExtVersionSql -join "`n")
                      ELSE sys.BuildExt
                    END AS char) as BuildExt
                from vSMS_TaskSequenceExecutionStatus tes
                inner join v_R_System sys on tes.ResourceID = sys.ResourceID
                inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                where tsp.Name = @TS
                and DATEDIFF(hour,(CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, ExecutionTime), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) ),GETDATE()) <= @TimePeriod
                and ExitCode not in ($ExitCodeSanitized)
                and tes.LastStatusMsgID not in ($DisabledStepSanitized)
                ORDER BY Name0 Desc
            "
            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $command.Parameters.AddWithValue("@TimePeriod", [int]$TimePeriod) | Out-Null
            $result = $command.ExecuteReader()
            $table = New-Object -TypeName 'System.Data.DataTable'
            $table.Load($result)
            $result.Dispose()
            $command.Dispose()
             
            # Gather results into PS object    
            $PCResults = foreach ($Row in $table.Rows)
            {
                [pscustomobject]@{
                    ComputerName = $Row.Name0
                    GUID         = $Row.GUID
                    BuildExt     = $Row.BuildExt
                }
            }

            $FinalComputerNameList = foreach ($pc in $PCResults) {
                [pscustomobject]@{ DisplayName = $pc.ComputerName; Value = $pc.GUID }
            }
            $BuildVersions = [String]::Join('; ', @($PCResults | Select-Object -Property BuildExt | Group-Object BuildExt | Sort-Object Count -Descending | ForEach-Object { "$($_.Name.Trim()) = $($_.Count)" }) )
            $deviceCount = if ($PCResults) { @($PCResults).Count } else { 0 }

            $FinalComputerNameList = [Array]($FinalComputerNameList + [pscustomobject]@{ DisplayName = "-All-"; Value = 0 })
             
            # Display results in ComputerName combobox     
                $hash.Window.Dispatcher.Invoke(
                [action]{
                    $selectedComp = $hash.ComputerName.SelectedItem
                    $selectedText = $hash.ComputerName.Text
                    $selectedName = if ($selectedComp -is [System.Management.Automation.PSCustomObject]) {
                        $selectedComp.DisplayName
                    } elseif (-not [string]::IsNullOrWhiteSpace($selectedText)) {
                        $selectedText
                    } else {
                        $null
                    }

                    $hash.ComputerName.ItemsSource = [Array]$FinalComputerNameList
                    $hash.ComputerName.DisplayMemberPath = "DisplayName"

                    if ($selectedName) {
                        $match = $FinalComputerNameList | Where-Object { $_.DisplayName -eq $selectedName } | Select-Object -First 1
                        if ($match) {
                            $hash.ComputerName.SelectedItem = $match
                        } else {
                            $hash.ComputerName.Text = $selectedName
                        }
                    }

                    $hash.BuildExt.Text = $BuildVersions
                    if ($hash.DeviceCount) { $hash.DeviceCount.Text = $deviceCount }
            })
        }
        catch {
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    if ($hash.DeviceCount) { $hash.DeviceCount.Text = 0 }
            })
        }
        finally
        {
            if ($connection -and $connection.State -ne [System.Data.ConnectionState]::Closed)
            {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    # Set variables from Hash table
    $SQLServer = $hash.SQLServer.Text
    $Database = $hash.Database.Text
    $TimePeriod = $hash.TimePeriod.Text
	$SuccessCode = $hash.SuccessCode.Text
    $ErrorsOnly = $hash.ErrorsOnly.IsChecked
	$DisabledSteps = $hash.DisabledSteps.IsChecked
    $TS = $hash.TaskSequence.SelectedItem

    $filterParams = Get-FilterParams -ErrorsOnly $ErrorsOnly -SuccessCode $SuccessCode -DisabledSteps $DisabledSteps
    $ExitCodeSanitized = $filterParams.ExitCodeSanitized
    $DisabledStepSanitized = $filterParams.DisabledStepSanitized

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($BuildExtVersionSql).AddArgument($TimePeriod).AddArgument($ExitCodeSanitized).AddArgument($DisabledStepSanitized).AddArgument($TS)
    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ActionNames 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$TimePeriod,$ExitCodeSanitized,$DisabledStepSanitized,$TS)

        # Connect to SQL Server
        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        try
        {
            $connectionString = "Server=$SQLServer;Database=$Database;Integrated Security=SSPI;Connect Timeout=5;"
            $connection.ConnectionString = $connectionString
            $connection.Open()

            # Run SQL query
            $Query = "
                Select Distinct ActionName
                from vSMS_TaskSequenceExecutionStatus tes
                inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                where tsp.Name = @TS
                and DATEDIFF(hour,(CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, ExecutionTime), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) ),GETDATE()) <= @TimePeriod
                and ExitCode not in ($ExitCodeSanitized)
                and tes.LastStatusMsgID not in ($DisabledStepSanitized)
                ORDER BY ActionName ASC
            "
            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $command.Parameters.AddWithValue("@TimePeriod", [int]$TimePeriod) | Out-Null
            $result = $command.ExecuteReader()
            $table = New-Object -TypeName 'System.Data.DataTable'
            $table.Load($result)
            $result.Dispose()
            $command.Dispose()
             
            # Gather results into PS object    
            $PCResults = foreach ($Row in $table.Rows)
            {
                $Row.ActionName
            }
            
            $FinalActionNameList = [Array]($PCResults) + '-All-'
             
            # Display results in ActionName combobox     
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $selectedAction = $hash.ActionName.SelectedItem
                    $selectedActionText = $hash.ActionName.Text

                    $hash.ActionName.ItemsSource = [Array]$FinalActionNameList

                    $targetAction = if ($selectedAction) { $selectedAction } elseif ($selectedActionText) { $selectedActionText } else { $null }
                    if ($targetAction) {
                        $match = $FinalActionNameList | Where-Object { $_ -eq $targetAction } | Select-Object -First 1
                        if ($match) {
                            $hash.ActionName.SelectedItem = $match
                        }
                    }
            })
        }
        catch {
            $MyError = $_.Exception.Message
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ActionOutput.Text = "[ERROR] Could not populate action names: $MyError"
            })
        }
        finally
        {
            if ($connection -and $connection.State -ne [System.Data.ConnectionState]::Closed)
            {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    # Set variables from Hash table
    $SQLServer = $hash.SQLServer.Text
    $Database = $hash.Database.Text
    $TimePeriod = $hash.TimePeriod.Text
	$SuccessCode = $hash.SuccessCode.Text
    $ErrorsOnly = $hash.ErrorsOnly.IsChecked
	$DisabledSteps = $hash.DisabledSteps.IsChecked
    $TS = $hash.TaskSequence.SelectedItem

    $filterParams = Get-FilterParams -ErrorsOnly $ErrorsOnly -SuccessCode $SuccessCode -DisabledSteps $DisabledSteps
    $ExitCodeSanitized = $filterParams.ExitCodeSanitized
    $DisabledStepSanitized = $filterParams.DisabledStepSanitized

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($TimePeriod).AddArgument($ExitCodeSanitized).AddArgument($DisabledStepSanitized).AddArgument($TS)
    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

function Dispose-PSInstances 
{
    if ($null -eq $script:PSInstances) { return }
    $remaining = @()
    $running = @()
    foreach ($PSinstance in $script:PSInstances)
    {
        if ($null -ne $PSinstance)
        {
            if ($PSinstance.InvocationStateInfo.State -in 'Completed', 'Failed', 'Stopped')
            {
                try { $PSinstance.Dispose() } catch { }
            }
            else
            {
                $running += $PSinstance
            }
        }
    }
    $script:PSInstances = $remaining

    if ($running.Count -gt 0)
    {
        $cleanup = {
            foreach ($PSinstance in $running)
            {
                try { $PSinstance.Stop() } catch { }
                finally { try { $PSinstance.Dispose() } catch { } }
            }
        }.GetNewClosure()
        [System.Threading.Tasks.Task]::Run([Action]$cleanup) | Out-Null
    }
}

Function Create-Timer 
{
    if ($global:Timer)
    {
        $global:Timer.Stop()
        $global:Timer.Dispose()
    }
    $global:Timer = New-Object -TypeName System.Windows.Forms.Timer
    $timer.Interval = Get-RefreshIntervalMilliseconds
    $timer.add_Tick({
        Populate-ComputerNames -hash $hash -RunspacePool $RunspacePool
        Populate-ActionNames -hash $hash -RunspacePool $RunspacePool
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
    })
}

Function Get-RefreshIntervalMilliseconds
{
    $minutes = 0
    if (-not [int]::TryParse([string]$hash.RefreshPeriod.Text, [ref]$minutes) -or $minutes -lt 1)
    {
        $minutes = 5
    }
    return $minutes * 60000
}

Function Start-Timer 
{
    if ($timer)
    {
        $timer.Start()
    }
}

Function Stop-Timer 
{
    if ($timer)
    {
        $timer.Stop()
    }
}

Function Update-ConfigFile 
{
    param($hash)
    $XML_Config = Join-Path $currentLocation "Config.xml"
    If (Test-Path $XML_Config){
        [xml]$Get_Config = Get-Content $XML_Config

        $Get_Config.Config.sql = $hash.SQLServer.Text
        $Get_Config.Config.db = $hash.Database.Text
        $Get_Config.Config.dtformat = $hash.DTFormat.SelectedItem
        if ($hash.GreyDisabledSteps) {
            if (-not $Get_Config.Config.greydisabledsteps) {
                $node = $Get_Config.CreateElement("greydisabledsteps")
                $null = $Get_Config.Config.AppendChild($node)
            }
            $Get_Config.Config.greydisabledsteps = $hash.GreyDisabledSteps.IsChecked.ToString()
            $Global:GreyDisabledSteps = $hash.GreyDisabledSteps.IsChecked
        }
        
        $Get_Config.Save((Resolve-Path $XML_Config))
    }
}

Function Read-ConfigFile
{
	$XML_Config = Join-Path $currentLocation "Config.xml"
	If (Test-Path $XML_Config){
		[xml]$Get_Config = Get-Content $XML_Config
		
		$regsql = $Get_Config.Config.sql
        $regdb = $Get_Config.Config.db
        $regdtformat = $Get_Config.Config.dtformat
        $reggreydisabledsteps = $Get_Config.Config.greydisabledsteps
	}
    if (![string]::IsNullOrWhiteSpace($regsql))
    {
        $hash.SQLServer.Text = $regsql
    }
    if (![string]::IsNullOrWhiteSpace($regdb))
    {
        $hash.Database.Text = $regdb
    }

    if (![string]::IsNullOrWhiteSpace($reggreydisabledsteps)) {
        $Global:GreyDisabledSteps = ($reggreydisabledsteps -notin 'False', 'false', '0')
    } else {
        $Global:GreyDisabledSteps = $true
    }

    if ($hash.GreyDisabledSteps) {
        $hash.GreyDisabledSteps.IsChecked = $Global:GreyDisabledSteps
    }

    if (![string]::IsNullOrWhiteSpace($regdtformat))
    {
        if ($regdtformat -eq 'UTC')
        {
            if (!$CurrentDateTimeF)
            {
                $Global:CurrentDateTimeF = 'UTC'
            }
        }
    }
}

Function Generate-Report 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$StartDate,$EndDate,$TS,$DTFormat)
        
        if ($DTFormat -ne 'UTC')
        {
            [datetime]$StartDate = $StartDate.ToUniversalTime()
            [datetime]$EndDate = $EndDate.ToUniversalTime()
        }

        # Set dates to ISO standard format for SQL Server
        $SQLStart = $StartDate | Get-Date -Format s
        $SQLEnd = $EndDate | Get-Date -Format s

        $hash.Window.Dispatcher.Invoke(
            [action]{
                $hash.Working.Content = 'Working...'
                $hash.ReportProgress.Visibility = 'Visible'
                $hash.ReportProgress.Value = 10
        })

        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        try
        {
            $connectionString = "Server=$SQLServer;Database=$Database;Integrated Security=SSPI;Connect Timeout=5;"
            $connection.ConnectionString = $connectionString
            $connection.Open()

            # Find all resourceID for TS steps between the selected dates
            $Query = "
                select distinct tes.ResourceID
                from vSMS_TaskSequenceExecutionStatus tes
                inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                where tsp.Name = @TS
                and tes.ExecutionTime >= @SQLStart
                and tes.ExecutionTime <= @SQLEnd
            "

            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $command.Parameters.AddWithValue("@SQLStart", $SQLStart) | Out-Null
            $command.Parameters.AddWithValue("@SQLEnd", $SQLEnd) | Out-Null
            $reader = $command.ExecuteReader()
            $table = New-Object -TypeName 'System.Data.DataTable'
            $table.Load($reader)
            $reader.Dispose()
            $command.Dispose()

            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ReportProgress.Value = 20
            })

            $ResultsList = foreach ($ResourceID in $table.Rows.ResourceID)
            {
                $Query = "
                    Select (select top(1) convert(datetime,ExecutionTime,121)
                    from vSMS_TaskSequenceExecutionStatus tes
                    inner join v_R_System sys on tes.ResourceID = sys.ResourceID
                    inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                    where tsp.Name = @TS
                    and tes.ExecutionTime >= @SQLStart 
                    and tes.ExecutionTime <= @SQLEnd
                    and LastStatusMsgName = 'The task sequence execution engine started execution of a task sequence'
                    and Step = 0
                    and tes.ResourceID = @ResourceID
                    order by ExecutionTime desc) as 'Start',
                    (select top(1) convert(datetime,ExecutionTime,121)
                    from vSMS_TaskSequenceExecutionStatus tes
                    inner join v_R_System sys on tes.ResourceID = sys.ResourceID
                    inner join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                    where tsp.Name = @TS
                    and tes.ExecutionTime >= @SQLStart
                    and tes.ExecutionTime <= @SQLEnd
                    and LastStatusMsgName = 'The task sequence execution engine successfully completed a task sequence'
                    and tes.ResourceID = @ResourceID
                    order by ExecutionTime desc) as 'Finish',
                    (Select name0 from v_R_System sys where sys.ResourceID = @ResourceID) as 'ComputerName',
                    (select Model0 from v_GS_Computer_System comp where comp.ResourceID = @ResourceID) as 'Model'
                "
                $command = $connection.CreateCommand()
                $command.CommandText = $Query
                $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
                $command.Parameters.AddWithValue("@SQLStart", $SQLStart) | Out-Null
                $command.Parameters.AddWithValue("@SQLEnd", $SQLEnd) | Out-Null
                $command.Parameters.AddWithValue("@ResourceID", [int]$ResourceID) | Out-Null
                $reader = $command.ExecuteReader()
                $subTable = New-Object -TypeName 'System.Data.DataTable'
                $subTable.Load($reader)
                $reader.Dispose()
                $command.Dispose()

                # A device can have status rows in the selected period but no
                # matching start/finish record. Do not abort the whole report
                # when that happens.
                if ($subTable.Rows.Count -eq 0)
                {
                    continue
                }

                $startValue = $subTable.Rows[0].Start
                if ($null -eq $startValue -or $startValue -is [System.DBNull])
                {
                    $Start = ''
                }
                Else 
                {
                    if ($DTFormat -eq 'UTC')
                    {
                        $Start = $startValue
                    }
                    Else 
                    {
                        $Start = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$startValue, [System.TimeZoneInfo]::Local)
                    }
                }

                $finishValue = $subTable.Rows[0].Finish
                if ($null -eq $finishValue -or $finishValue -is [System.DBNull])
                {
                    $Finish = ''
                }
                Else 
                {
                    if ($DTFormat -eq 'UTC')
                    {
                        $Finish = $finishValue
                    }
                    Else 
                    {
                        $Finish = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$finishValue, [System.TimeZoneInfo]::Local)
                    }
                }

                if ($Start -eq '' -or $Finish -eq '')
                {
                    $diffStr = ''
                }
                else 
                {
                    $diff = [datetime]$Finish - [datetime]$Start
                    $diffStr = "$($diff.Hours) hours $($diff.Minutes) minutes"
                }

                [pscustomobject]@{
                    ComputerName   = $subTable.Rows[0].ComputerName
                    StartTime      = $Start
                    FinishTime     = $Finish
                    DeploymentTime = $diffStr
                    Model          = $subTable.Rows[0].Model
                }
            }

            $Results = $ResultsList | Sort-Object -Property ComputerName

                $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ReportProgress.Value = 50
            })

            $Query = "
                select sys.Name0 as 'ComputerName',
                tsp.Name 'Task Sequence',
                comp.Model0 as Model,
                tes.ExecutionTime,
                tes.Step,
                tes.GroupName,
                tes.ActionName,
                tes.LastStatusMsgName,
                tes.ExitCode,
                tes.ActionOutput
                from vSMS_TaskSequenceExecutionStatus tes
                left join v_R_System sys on tes.ResourceID = sys.ResourceID
                left join v_TaskSequencePackage tsp on tes.PackageID = tsp.PackageID
                left join v_GS_COMPUTER_SYSTEM comp on tes.ResourceID = comp.ResourceID
                where tsp.Name = @TS
                and tes.ExecutionTime >= @SQLStart
                and tes.ExecutionTime <= @SQLEnd
                and tes.ExitCode not in (0,-2147467259)
                Order by tes.ExecutionTime desc
            "

            $command = $connection.CreateCommand()
            $command.CommandText = $Query
            $command.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $command.Parameters.AddWithValue("@SQLStart", $SQLStart) | Out-Null
            $command.Parameters.AddWithValue("@SQLEnd", $SQLEnd) | Out-Null
            $reader = $command.ExecuteReader()
            $errTable = New-Object -TypeName 'System.Data.DataTable'
            $errTable.Load($reader)
            $reader.Dispose()
            $command.Dispose()

            if ($DTFormat -ne 'UTC')
            {
                foreach ($row in $errTable.Rows)
                {
                    $executionTime = $row['ExecutionTime']
                    if ($null -eq $executionTime -or $executionTime -is [System.DBNull]) {
                        continue
                    }

                    $row['ExecutionTime'] = [System.TimeZoneInfo]::ConvertTimeFromUtc(
                        [datetime]$executionTime,
                        [System.TimeZoneInfo]::Local
                    )
                }
            }

                $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ReportProgress.Value = 80
            })

            if ($DTFormat -ne 'UTC')
            {
                $StartDate = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$StartDate, [System.TimeZoneInfo]::Local)
                $EndDate = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$EndDate, [System.TimeZoneInfo]::Local)
            }         

            # Create html email
            $style = @"
<style>
body {
    color:#012E34;
    font-family:Calibri,Tahoma;
    font-size: 10pt;
}
h1 {
    text-align:center;
}
h2 {
    border-top:1px solid #666666;
}
 
th {
    font-weight:bold;
    color:#012E34;
    background-color:#69969C;
}
.odd  { background-color:#012E34; }
.even { background-color:#012E34; }
</style>
"@

            $HEaders = @"
<H1>Task Sequence Execution Summary Report</H1>
<H3>Starting Date: $StartDate</H3>
<H3>End Date: $EndDate</H3>
<H3>Task Sequence: $TS</H3>
<H3>TimeZone for Date/Time: $DTFormat</H3>
"@

            $body1 = $Results | 
            Select-Object -Property ComputerName, StartTime, FinishTime , DeploymentTime, Model |
            ConvertTo-Html -Head $style -Body "<H2>Task Sequence Executions ($($Results.Count))</H2>" | 
            Out-String

            $body2 = $errTable | 
            Select-Object -Property ComputerName, 'Task Sequence', Model, ExecutionTime, Step, GroupName, ActionName, LastStatusMsgName, ExitCode |
            ConvertTo-Html -Head $style -Body "<H2>Task Sequence Execution Errors ($($errTable.Rows.Count))</H2>" | 
            Out-String

            $Body = $HEaders + $body1 + $body2

            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.Working.Content = ''
                    $hash.ReportProgress.Value = 100
            })

            $reportPath = Join-Path $env:temp "TSReport.htm"
            $Body | Out-File -FilePath $reportPath -Force
            Invoke-Item -Path $reportPath
        }
        catch 
        {
            $MyError = $_.Exception.Message
            $errorDetails = $_ | Format-List * -Force | Out-String
            $errorLogPath = Join-Path $env:TEMP 'ConfigMgrTSMonitor-ReportError.log'
            $errorDetails | Set-Content -Path $errorLogPath -Encoding UTF8
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.Working.Content = "Error: $MyError"
                    $hash.Working.ToolTip = "Full error details were written to: $errorLogPath`n`n$errorDetails"
                    $hash.ReportProgress.Value = 0
                    [System.Windows.MessageBox]::Show(
                        $hash.Window2,
                        "Report generation failed:`n`n$MyError`n`n$errorDetails",
                        'ConfigMgr Task Sequence Monitor',
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Error
                    ) | Out-Null
            })
        }
        finally
        {
            if ($connection -and $connection.State -ne [System.Data.ConnectionState]::Closed)
            {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    # Set variables from Hash table
    $SQLServer = $hash.SQLServer.Text
    $Database = $hash.Database.Text
    $DTFormat = $hash.DTFormat.SelectedItem
    [datetime]$StartDate = $hash.StartDate.Text | Get-Date -Format "MM'/'dd'/'yyyy HH':'mm':'ss"
    [datetime]$EndDate = $hash.EndDate.Text | Get-Date -Format "MM'/'dd'/'yyyy HH':'mm':'ss"
    $EndDate = $EndDate.AddDays(1).AddSeconds(-1)
    $TS = $hash.TSList.SelectedItem

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($StartDate).AddArgument($EndDate).AddArgument($TS).AddArgument($DTFormat)
    $script:PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Show-ConfigWindow 
{
    param (
        [string]$ActiveTab = 'Settings'
    )
    $configXamlPath = Join-Path $currentLocation "XAML\Config.xaml"
    [xml]$xaml2 = Get-Content $configXamlPath
    $reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml2)
    $hash.Window2 = [Windows.Markup.XamlReader]::Load($reader)
    $hash.SQLServer = $hash.Window2.FindName('SQLServer')
    $hash.Database = $hash.Window2.FindName('Database')
    $hash.ConnectSQL = $hash.Window2.FindName('ConnectSQL')
    $hash.TSList = $hash.Window2.FindName('TSList')
    $hash.StartDate = $hash.Window2.FindName('StartDate')
    $hash.EndDate = $hash.Window2.FindName('EndDate')
    $hash.GenerateReport = $hash.Window2.FindName('GenerateReport')
    $hash.SettingsTab = $hash.Window2.FindName('SettingsTab')
    $hash.ReportTab = $hash.Window2.FindName('ReportTab')
    $hash.Tabs = $hash.Window2.FindName('Tabs')
    $hash.Runasadmin = $hash.Window2.FindName('Runasadmin')
    $hash.Working = $hash.Window2.FindName('Working')
    $hash.ReportProgress = $hash.Window2.FindName('ReportProgress')
    $hash.Link1 = $hash.Window2.FindName('Link1')
    $hash.Link2 = $hash.Window2.FindName('Link2')
    $hash.DTFormat = $hash.Window2.FindName('DTFormat')
    $hash.GreyDisabledSteps = $hash.Window2.FindName('GreyDisabledSteps')

    Read-ConfigFile

    if ($ActiveTab -eq 'Report') {
        $hash.ReportTab.Focus()
    } else {
        $hash.SettingsTab.Focus()
    }

    if (!(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')))
    {
        $hash.Runasadmin.Visibility = 'Visible'
    }

    $hash.TSList.ItemsSource = @($hash.TaskSequences)
    $hash.DTFormat.ItemsSource = $global:Timezones.TimeZone

    if ($Global:CurrentDateTimeF -eq 'UTC')
    {
        $hash.DTFormat.SelectedIndex = 0
    }
    else 
    {
        $hash.DTFormat.SelectedIndex = 1
    }

    $hash.SQLServer.Add_GotMouseCapture({
        if ($hash.SQLServer.Text -eq '<SQLServer\Instance>') { $hash.SQLServer.Text = '' }
    })
    $hash.SQLServer.Add_GotKeyboardFocus({
        if ($hash.SQLServer.Text -eq '<SQLServer\Instance>') { $hash.SQLServer.Text = '' }
    })
    $hash.Database.Add_GotMouseCapture({
        if ($hash.Database.Text -eq '<Database>') { $hash.Database.Text = '' }
    })
    $hash.Database.Add_GotKeyboardFocus({
        if ($hash.Database.Text -eq '<Database>') { $hash.Database.Text = '' }
    })

    $hash.ConnectSQL.Add_Click({
        Update-ConfigFile -hash $hash
        Get-TaskSequenceList -hash $hash -RunspacePool $RunspacePool
    })

    $hash.GenerateReport.Add_Click({
        Generate-Report -hash $hash -RunspacePool $RunspacePool
    })

    if ($hash.Link1) {
        $hash.Link1.Add_Click({
            Start-Process -FilePath 'http://smsagent.wordpress.com/tools/configmgr-task-sequence-monitor/'
        })
    }

    if ($hash.Link2) {
        $hash.Link2.Add_Click({
            Start-Process -FilePath 'https://github.com/stephannn/ConfigMgr-Task-Sequence-Monitor'
        })
    }

    $hash.DTFormat.Add_SelectionChanged({
        $Global:CurrentDateTimeF = $hash.DTFormat.SelectedItem
    })

    $hash.Window2.Add_Closed({
        Update-ConfigFile -hash $hash
        if ($hash.TaskSequence -and $hash.TaskSequence.SelectedItem) {
            Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        }
    })

    $Null = $hash.Window2.ShowDialog()
}

#endregion

#region Event Handlers

$hash.Window.Add_ContentRendered({
		Read-ConfigFile
        Get-DateTimeFormat
        Get-TaskSequenceList -hash $hash -RunspacePool $RunspacePool
})

$hash.TaskSequence.Add_SelectionChanged({
        $Count = $hash.ComputerName.Items.Count
        $hash.Window.Dispatcher.Invoke(
            [action]{
                $hash.ComputerName.SelectedIndex = ($Count -1)
        })
        Dispose-PSInstances
        Populate-ComputerNames -hash $hash -RunspacePool $RunspacePool
		Populate-ActionNames -hash $hash -RunspacePool $RunspacePool
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Stop-Timer
        Create-Timer
        Start-Timer
        $Global:CurrentTS = $hash.TaskSequence.SelectedItem
})

$hash.ErrorsOnly.Add_Checked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.DisabledSteps.Add_Checked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.ErrorsOnly.Add_Unchecked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.DisabledSteps.Add_Unchecked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.SkippedSteps.Add_Checked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.SkippedSteps.Add_Unchecked({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Start-Timer
})

$hash.DataGrid.Add_SelectionChanged({
        Dispose-PSInstances
        Populate-ActionOutput -hash $hash -RunspacePool $RunspacePool
})

$hash.RefreshNow.Add_Click({
        Dispose-PSInstances
        Stop-Timer
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
        Populate-ComputerNames -hash $hash -RunspacePool $RunspacePool
		Populate-ActionNames -hash $hash -RunspacePool $RunspacePool
        $timer.Interval = Get-RefreshIntervalMilliseconds
        Start-Timer
})

$hash.ComputerName.Add_SelectionChanged({
        if ($hash.TaskSequence.SelectedItem -eq $CurrentTS)
        {
            Dispose-PSInstances
            Stop-Timer
            Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
            Start-Timer
        }
})

$hash.ActionName.Add_SelectionChanged({
        if ($hash.TaskSequence.SelectedItem -eq $CurrentTS)
        {
            Dispose-PSInstances
            Stop-Timer
            Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
            Start-Timer
        }
})

$hash.TimePeriod.Add_KeyDown({
        if ($_.Key -eq 'Return')
        {
            Dispose-PSInstances
            Stop-Timer
            Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
            Populate-ComputerNames -hash $hash -RunspacePool $RunspacePool
            $timer.Interval = Get-RefreshIntervalMilliseconds
            Start-Timer
        }
})

$hash.RefreshPeriod.Add_TextChanged({
        Stop-Timer
        $timer.Interval = Get-RefreshIntervalMilliseconds
        Start-Timer
})

$hash.SettingsButton.Add_Click({
        Show-ConfigWindow -ActiveTab 'Settings'
})

$hash.ReportButton.Add_Click({
        Show-ConfigWindow -ActiveTab 'Report'
})

$hash.Window.Add_Closed({
        Stop-Timer
        Dispose-PSInstances
        $RunspacePool.close()
        $RunspacePool.Dispose()
})

# Clean up WinForms message loop on closing
$hash.window.Add_Closing({[System.Windows.Forms.Application]::Exit()})
#endregion


# Make PowerShell Disappear unless in debug mode
if (-not $debug) {
	$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' 
	$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru 
	$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}

$app = New-Object Windows.Application
$app.Run($hash.Window)


