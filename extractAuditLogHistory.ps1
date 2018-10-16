#Script extracts Power BI Audit log history data for each day in the set range
#Output is JSON, can be modified to output as CSV
#Data is partitioned by date YYYY/MM/DD/auditLog.json
Set-ExecutionPolicy RemoteSigned

#Set Base Output Path
$basePath = "C:\Temp\Audit"
$outputFileName = "pbiaudit.json"

#Prompt User for credentials
$userCredential = Get-Credential

#Set credentials for automation
#$user = "username@domain.com"
#$pass = ConvertTo-SecureString -String "SecurePassword" -AsPlainText -Force
#$userCredential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $pass

#Create Session
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $session

#Set dates
#-baseDate establishes out starting point
#-startDate is the beginning of our range
#-endDate is the tail of our range
#-scriptStart is the logged starting timestamp
$baseDate=[datetime]::Today
$startDate=$baseDate
$endDate=$baseDate
$scriptStart=(get-date)

#Define session name
$sessionName = (get-date -Format 'u')+'pbiauditlog'

#Days in history to load 
#-number is iterating backwords
#-should be negative
#-default maximum retention is 90 days
$range = -11

$n = -1 #Set Reverse loop iterator 

#Loop through each day in range
Do {

    #Set Date Range for query
    $endDate = $startDate
    $startDate = $baseDate.AddDays($n)
    
    #Set results accumulator
    $aggregateResults = @()
    
    $i = 0 #Set Loop counter

    #Loop through result set
    Do { 
        #Fetch data from audit service
        $currentResults = Search-UnifiedAuditLog -StartDate $startDate -EndDate $enddate -SessionId $sessionName -SessionCommand ReturnLargeSet -ResultSize 1000 -RecordType PowerBI
        
        if ($currentResults.Count -gt 0) {
            Write-Host ("  Finished {3} search #{1}, {2} records: {0} min" -f [math]::Round((New-TimeSpan -Start $scriptStart).TotalMinutes,4), $i, $currentResults.Count, $user.UserPrincipalName )
            
            #Add results to accumulator
            $aggregateResults += $currentResults
            
            #Check result count to determine if loop continues
            if ($currentResults.Count -lt 1000) {
                #Results lt threshold - clear results object
                $currentResults = @()
            } else {
                #More results, increment counter
                $i++
            }
        }
    } Until ($currentResults.Count -eq 0)
    
    $data=@()
    
    #Loop through result log items
    foreach ($auditlogitem in $aggregateResults) {
        $datum = New-Object –TypeName PSObject
        $d=convertfrom-json $auditlogitem.AuditData
        $datum | Add-Member –MemberType NoteProperty –Name Id –Value $d.Id
        $datum | Add-Member –MemberType NoteProperty –Name CreationTime –Value $auditlogitem.CreationDate
        $datum | Add-Member –MemberType NoteProperty –Name CreationTimeUTC –Value $d.CreationTime
        $datum | Add-Member –MemberType NoteProperty –Name RecordType –Value $d.RecordType
        $datum | Add-Member –MemberType NoteProperty –Name Operation –Value $d.Operation
        $datum | Add-Member –MemberType NoteProperty –Name OrganizationId –Value $d.OrganizationId
        $datum | Add-Member –MemberType NoteProperty –Name UserType –Value $d.UserType
        $datum | Add-Member –MemberType NoteProperty –Name UserKey –Value $d.UserKey
        $datum | Add-Member –MemberType NoteProperty –Name Workload –Value $d.Workload
        $datum | Add-Member –MemberType NoteProperty –Name UserId –Value $d.UserId
        $datum | Add-Member –MemberType NoteProperty –Name ClientIP –Value $d.ClientIP
        $datum | Add-Member –MemberType NoteProperty –Name UserAgent –Value $d.UserAgent
        $datum | Add-Member –MemberType NoteProperty –Name Activity –Value $d.Activity
        $datum | Add-Member –MemberType NoteProperty –Name ItemName –Value $d.ItemName
        $datum | Add-Member –MemberType NoteProperty –Name WorkSpaceName –Value $d.WorkSpaceName
        $datum | Add-Member –MemberType NoteProperty –Name DashboardName –Value $d.DashboardName
        $datum | Add-Member –MemberType NoteProperty –Name DatasetName –Value $d.DatasetName
        $datum | Add-Member –MemberType NoteProperty –Name ReportName –Value $d.ReportName
        $datum | Add-Member –MemberType NoteProperty –Name WorkspaceId –Value $d.WorkspaceId
        $datum | Add-Member –MemberType NoteProperty –Name ObjectId –Value $d.ObjectId
        $datum | Add-Member –MemberType NoteProperty –Name DashboardId –Value $d.DashboardId
        $datum | Add-Member –MemberType NoteProperty –Name DatasetId –Value $d.DatasetId
        $datum | Add-Member –MemberType NoteProperty –Name ReportId –Value $d.ReportId
        $datum | Add-Member –MemberType NoteProperty –Name OrgAppPermission –Value $d.OrgAppPermission
        $datum | Add-Member –MemberType NoteProperty –Name Datasets –Value (ConvertTo-Json $d.Datasets)
        
        $data+=$datum
    }
    
    #Set Partitioned Output Dir
    $path = ("{0}\{1}" -f $basePath, $startDate.ToString("yyyy\\MM\\dd"))
    
    #Check Exists, Create if not
    If(!(Test-Path $path)){
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
    
    #Append Filename & Path
    $fullPath = ("{0}\{1}" -f $path, $outputFileName)
    
    #Output Console Logging
    Write-Host (" writing to file {0} - {1}" -f $fullPath, $startDate.ToString("yyyyMMdd"))
    
    #Output File
    #-empty file is output if no records are extracted
    $data | ConvertTo-Json -depth 100 | Out-File $fullPath -Force
    
    $n-- #Set previous day
} Until ($n -lt $range)

#Clean up
Remove-PSSession -Id $session.Id