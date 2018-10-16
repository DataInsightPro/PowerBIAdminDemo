#Install-Module -Name MicrosoftPowerBIMgmt

Connect-PowerBIServiceAccount

#List Workspaces for current user
$workspaces = Get-PowerBIWorkspace
$workspaces
$workspaces.Count

#List All tenant Workspaces
$workspace_all = Get-PowerBIWorkspace -Scope Organization
$workspace_all
$workspace_all.Count

#Get a report count for User Workspaces
foreach ($workspace in $workspaces) {
    $reports = Get-PowerBIReport -Scope Organization -WorkspaceId $workspace.Id
    ("Workspace {0} has {1} reports." -f $workspace.Name, $reports.Count)
}

#Invoke REST API
#-get Data Gateways
Invoke-PowerBIRestMethod -Url 'gateways' -Method Get

Disconnect-PowerBIServiceAccount