#
# Todo : Close related alert
#
[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory=$false)]
    [object] $WebhookData
)

if ($WebhookData) {
    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    # Get the info needed to identify the VM (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId

    Write-output "schemaId: $schemaId" -Verbose
    
    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object] ($WebhookBody.data).essentials
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + "/" + ($alertTargetIdArray)[7]
        $ResourceName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition

    }
    elseif ($schemaId -eq "AzureMonitorMetricAlert") {
        # This is the near-real-time Metric Alert schema
        $AlertContext = [object] ($WebhookBody.data).context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/activityLogs") {
        # This is the Activity Log Alert schema
        $AlertContext = [object] (($WebhookBody.data).context).activityLog
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split("/"))[-1]
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq $null) {
        # This is the original Metric Alert schema
        $AlertContext = [object] $WebhookBody.context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = $WebhookBody.status
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    Write-Verbose "status: $status" -Verbose
    Write-Verbose "Resource Type: $ResourceType"
    if (($status -eq "Activated") -or ($status -eq "Fired")) {
        #if ($ResourceType -ne "Microsoft.Network/applicationGateways") {
            $connectionName = "AzureRunAsConnection"
            try {
                $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName                    
                Write-output "Logging in to Azure..."
                Connect-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
            }
            catch {
                if (!$servicePrincipalConnection)
                {
                    $ErrorMessage = "Connection $connectionName not found."
                    throw $ErrorMessage
                } else{
                    Write-Error -Message $_.Exception
                    throw $_.Exception
                }
            }
            Write-output "Successfully authenticated to Azure."

            $Assignements = Get-AzRoleAssignment -ResourceGroupName fabien-test | ? { $_.RoleDefinitionName -eq "Contributor" }
            $Assignements.ObjectId | % {

                Write-Output "Removing rights for ObjetID: $($_)"
                Remove-AzRoleAssignment -ResourceGroupName $ResourceGroupName -ObjectId $_ -RoleDefinitionName "Contributor"
            }

            
           
        }
    }
    else {
        # The alert status was not 'Activated' or 'Fired' so no action taken
        Write-Verbose ("No action taken. Alert status: " + $status) -Verbose
    }
}
else {
    # Error
    Write-Error "This runbook is meant to be started from an Azure alert webhook only."
}
