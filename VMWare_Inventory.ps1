$Output = @()
Get-View -SearchRoot (Get-Cluster '<datacenter>' | Get-View).MoRef -ViewType virtualmachine -Filter @{'Config.Template'='False'} | Select *, @{N="Disks";E={@($_.Guest.Disk.Length)}} | Sort-Object -Descending Disks | % {
    $VM = $_
    $prop = New-Object System.Collections.Specialized.OrderedDictionary
    $prop.add('Name',$VM.name)
    $prop.add('CPUSocket',$vm.config.hardware.NumCPU)
    $prop.add('CorePerSocket',$vm.config.hardware.NumCoresPerSocket)
    $Disk = 0
    $TotalSize = 0
    $VM.Guest.Disk | % {
        $prop.add("Disk$($Disk) Letter/Path",$_.DiskPath)
        $prop.add("Disk$($Disk) Capacity (GB)",[math]::Round($_.Capacity/ 1GB))
        $prop.add("Disk$($Disk) FreeSpace (GB)",[math]::Round($_.FreeSpace / 1GB))
        $TotalSize = $TotalSize + [math]::Round($_.Capacity/ 1GB)
        $Disk++
    }
    $prop.add('TotalSize',$TotalSize)
    $Output += [PSCustomObject]$prop
}

$Output