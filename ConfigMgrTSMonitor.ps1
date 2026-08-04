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

#region GUI and Variables
### Main Window ###
# GUI
$mainWindowXamlPath = Join-Path $currentLocation "XAML\MainWindow.xaml"
[xml]$xaml = Get-Content $mainWindowXamlPath

$BuildExtVersionSql = @()
$buildExtCsvPath = Join-Path $currentLocation "BuildExt.csv"
if (Test-Path $buildExtCsvPath) {
    Import-Csv -Path $buildExtCsvPath -Delimiter ";" -Header Build, Version | ForEach-Object {
        $BuildExtVersionSql += "WHEN sys.BuildExt like '$($_.Build)' THEN '$($_.Version)'"
    }
}

$hash = [hashtable]::Synchronized(@{})
$reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml)
$hash.Window = [Windows.Markup.XamlReader]::Load( $reader )
$global:PSInstances = @()
$Global:Timezones = @()

$hash.TaskSequence = $hash.Window.FindName('TaskSequence')
$hash.TimePeriod = $hash.Window.FindName('TimePeriod')
$hash.ErrorsOnly = $hash.Window.FindName('ErrorsOnly')
$hash.SuccessCode = $hash.Window.FindName('SuccessCode')
$hash.DisabledSteps = $hash.Window.FindName('DisabledSteps')
$hash.ComputerName = $hash.Window.FindName('ComputerName')
$hash.BuildExt = $hash.Window.FindName('BuildExt')
$hash.ActionName = $hash.Window.FindName('ActionName')
$hash.RefreshPeriod = $hash.Window.FindName('RefreshPeriod')
$hash.RefreshNow = $hash.Window.FindName('RefreshNow')
$hash.DataGrid = $hash.Window.FindName('DataGrid')
$hash.ActionOutput = $hash.Window.FindName('ActionOutput')
$hash.SettingsButton = $hash.Window.FindName('SettingsButton')
$hash.ReportButton = $hash.Window.FindName('ReportButton')
$hash.ErrorCount = $hash.Window.FindName('ErrorCount')

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

if (Test-Path -Path $gridIco1)
{
    $Hash.Window2.ShowInTaskbar = $true
}
if ($programFilesX86 -and (Test-Path -Path $gridIco2))
{
    $Hash.Window2.ShowInTaskbar = $true
}
if (Test-Path -Path $gridIcoLocal)
{
    $Hash.Window2.ShowInTaskbar = $true
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
    $PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Get-TaskSequenceData 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$BuildExtVersionSql,$TimePeriod,$SuccessCode,$ErrorsOnly,$DisabledSteps,$ComputerName,$ActionName,$TS,$DTFormat)

        # Notify of data retrieval         
        $hash.Window.Dispatcher.Invoke(
            [action]{
                $hash.ActionOutput.Text = 'Retrieving data...'
                $hash.DataGrid.ItemsSource = ''
        })

        if ($ErrorsOnly -eq 'True' -or $ErrorsOnly -eq $true)
        {
            $ExitCode = $SuccessCode
        }
        else 
        {
            $ExitCode = 999999999999999999999999
        }
		
		if ($DisabledSteps -eq 'True' -or $DisabledSteps -eq $true)
        {
            $DisabledStep = "''"
        }
        Else 
        {
            $DisabledStep = '11128'
        }

        $ExitCodeSanitized = if ($ExitCode -eq 999999999999999999999999) { "999999999" } else { ($ExitCode -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($ExitCodeSanitized)) { $ExitCodeSanitized = "999999999" }

        $SuccessCodeSanitized = ($SuccessCode -replace '[^0-9,-]', '')
        if ([string]::IsNullOrWhiteSpace($SuccessCodeSanitized)) { $SuccessCodeSanitized = "999999999" }

        $DisabledStepSanitized = if ($DisabledStep -eq "''") { "''" } else { ($DisabledStep -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($DisabledStepSanitized)) { $DisabledStepSanitized = "''" }
        
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

            $commandErr = $connection.CreateCommand()
            $commandErr.CommandText = $ErrQuery
            $commandErr.Parameters.AddWithValue("@TS", [string]$TS) | Out-Null
            $commandErr.Parameters.AddWithValue("@TimePeriod", [int]$TimePeriod) | Out-Null
            $commandErr.Parameters.AddWithValue("@SQLActionName", [string]$SQLActionName) | Out-Null
            $commandErr.Parameters.AddWithValue("@SQLComputerName", [string]$SQLComputerName) | Out-Null
            $erresult = $commandErr.ExecuteReader()
            $errtable = New-Object -TypeName 'System.Data.DataTable'
            $errtable.Load($erresult)

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

                $isSkipped = ($Row.LastStatusMsgID -eq 11128 -or $Row.LastStatusMsgName -like '*skipped*')

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
                }
            }

            $global:Results = [Array]$ResultsList

            if ($global:Results.Count -eq 1)
            {
                $i++
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
                    Record             = ' '
                    IsSkipped          = $false
                }
                $global:Results = [Array]($global:Results + $dummyObj)
            }

            $FilteredResults = $global:Results | Select-Object -Property IconPath, ComputerName, GUID, 'Connection Type', BuildExt, Model0, BIOSVersion, ExecutionTime, Step, ActionName, GroupName, LastStatusMsgName, ExitCode, Record, IsSkipped

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
    $ComputerName = $hash.ComputerName.SelectedItem
	$ActionName = $hash.ActionName.SelectedItem
    $TS = $hash.TaskSequence.SelectedItem
    $DTFormat = $hash.DTFormat.SelectedItem

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($BuildExtVersionSql).AddArgument($TimePeriod).AddArgument($SuccessCode).AddArgument($ErrorsOnly).AddArgument($DisabledSteps).AddArgument($ComputerName).AddArgument($ActionName).AddArgument($TS).AddArgument($DTFormat)

    $PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ActionOutput 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$Record)
        $msg = $global:Results | Where-Object { $_.Record -eq $Record } | Select-Object -First 1
        $hash.Window.Dispatcher.Invoke(
            [action]{
                $hash.ActionOutput.Text = $msg.ActionOutput
        })
    }

    # Set variables from Hash table
    $Record = $hash.DataGrid.SelectedItem.Record

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($Record)
    $PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ComputerNames 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$BuildExtVersionSql,$TimePeriod,$SuccessCode,$ErrorsOnly,$DisabledSteps,$TS)
        
        if ($ErrorsOnly -eq 'True' -or $ErrorsOnly -eq $true)
        {
            $ExitCode = $SuccessCode
        }
        else 
        {
            $ExitCode = 999999999999999999999999
        }
		
		if ($DisabledSteps -eq 'True' -or $DisabledSteps -eq $true)
        {
            $DisabledStep = "''"
        }
        Else 
        {
            $DisabledStep = '11128'
        }

        $ExitCodeSanitized = if ($ExitCode -eq 999999999999999999999999) { "999999999" } else { ($ExitCode -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($ExitCodeSanitized)) { $ExitCodeSanitized = "999999999" }

        $DisabledStepSanitized = if ($DisabledStep -eq "''") { "''" } else { ($DisabledStep -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($DisabledStepSanitized)) { $DisabledStepSanitized = "''" }

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

            $FinalComputerNameList = [Array]($FinalComputerNameList + [pscustomobject]@{ DisplayName = "-All-"; Value = 0 })
             
            # Display results in ComputerName combobox     
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ComputerName.ItemsSource = [Array]$FinalComputerNameList
                    $hash.ComputerName.DisplayMemberPath = "DisplayName"
                    $hash.BuildExt.Text = $BuildVersions
            })
        }
        catch {}
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

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($BuildExtVersionSql).AddArgument($TimePeriod).AddArgument($SuccessCode).AddArgument($ErrorsOnly).AddArgument($DisabledSteps).AddArgument($TS)
    $PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

Function Populate-ActionNames 
{
    param ($hash,$RunspacePool)

    $code = 
    {
        param($hash,$SQLServer,$Database,$TimePeriod,$SuccessCode,$ErrorsOnly,$DisabledSteps,$TS)
        
        if ($ErrorsOnly -eq 'True' -or $ErrorsOnly -eq $true)
        {
            $ExitCode = $SuccessCode
        }
        else 
        {
            $ExitCode = 999999999999999999999999
        }
		
		if ($DisabledSteps -eq 'True' -or $DisabledSteps -eq $true)
        {
            $DisabledStep = "''"
        }
        Else 
        {
            $DisabledStep = '11128'
        }

        $ExitCodeSanitized = if ($ExitCode -eq 999999999999999999999999) { "999999999" } else { ($ExitCode -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($ExitCodeSanitized)) { $ExitCodeSanitized = "999999999" }

        $DisabledStepSanitized = if ($DisabledStep -eq "''") { "''" } else { ($DisabledStep -replace '[^0-9,-]', '') }
        if ([string]::IsNullOrWhiteSpace($DisabledStepSanitized)) { $DisabledStepSanitized = "''" }

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
             
            # Gather results into PS object    
            $PCResults = foreach ($Row in $table.Rows)
            {
                $Row.ActionName
            }
            
            $FinalActionNameList = [Array]($PCResults) + '-All-'
             
            # Display results in ActionName combobox     
            $hash.Window.Dispatcher.Invoke(
                [action]{
                    $hash.ActionName.ItemsSource = [Array]$FinalActionNameList
            })
        }
        catch {}
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

    # Create PS instance in runspace pool and execute
    $PSinstance = [powershell]::Create().AddScript($code).AddArgument($hash).AddArgument($SQLServer).AddArgument($Database).AddArgument($TimePeriod).AddArgument($SuccessCode).AddArgument($ErrorsOnly).AddArgument($DisabledSteps).AddArgument($TS)
    $PSInstances += $PSinstance
    $PSinstance.RunspacePool = $RunspacePool
    $PSinstance.BeginInvoke()
}

function Dispose-PSInstances 
{
    foreach ($PSinstance in $PSInstances)
    {
        if ($PSinstance.InvocationStateInfo.State -eq 'Completed')
        {
            $PSinstance.Dispose()
        }
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
    $timer.Interval = [int]$hash.RefreshPeriod.Text * 60000
    $timer.add_Tick({
        Populate-ComputerNames -hash $hash -RunspacePool $RunspacePool
        Populate-ActionNames -hash $hash -RunspacePool $RunspacePool
        Get-TaskSequenceData -hash $hash -RunspacePool $RunspacePool
    })
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
	}
    if (![string]::IsNullOrWhiteSpace($regsql))
    {
        $hash.SQLServer.Text = $regsql
    }
    if (![string]::IsNullOrWhiteSpace($regdb))
    {
        $hash.Database.Text = $regdb
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

                if ($subTable.Rows[0].Start.GetType().Name -eq 'DBNull')
                {
                    $Start = ''
                }
                Else 
                {
                    if ($DTFormat -eq 'UTC')
                    {
                        $Start = $subTable.Rows[0].Start
                    }
                    Else 
                    {
                        $Start = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$subTable.Rows[0].Start, [System.TimeZoneInfo]::Local)
                    }
                }

                if ($subTable.Rows[0].Finish.GetType().Name -eq 'DBNull')
                {
                    $Finish = ''
                }
                Else 
                {
                    if ($DTFormat -eq 'UTC')
                    {
                        $Finish = $subTable.Rows[0].Finish
                    }
                    Else 
                    {
                        $Finish = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$subTable.Rows[0].Finish, [System.TimeZoneInfo]::Local)
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

            if ($DTFormat -ne 'UTC')
            {
                $newdates = foreach ($item in $errTable.Rows.ExecutionTime)
                {
                    [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$item, [System.TimeZoneInfo]::Local)
                }
                $i = -1
                $errTable.Rows.ExecutionTime | ForEach-Object -Process {
                    $i ++
                    $errTable.Rows[$i].ExecutionTime = $newdates[$i]
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
        catch {}
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
    $PSInstances += $PSinstance
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
        $timer.Interval = [int]$hash.RefreshPeriod.Text * 60000
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
            $timer.Interval = [int]$hash.RefreshPeriod.Text * 60000
            Start-Timer
        }
})

$hash.RefreshPeriod.Add_TextChanged({
        Stop-Timer
        $timer.Interval = [int]$hash.RefreshPeriod.Text * 60000
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


# Make PowerShell Disappear #comment our for development
if($debug){
	$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' 
	$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru 
	$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}

$app = New-Object Windows.Application
$app.Run($Hash.Window)
