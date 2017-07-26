#################################################################################
# @-Roy Berkowitz 2017-@
# Instructions:
# 1.) Place the CSV file named 'post-deploy.csv' into a folder of your choosing (Desktop works well) 
# 2.) Wherever you place the CSV, change the variable below $csvloc to that path
# 3.) Find the Variable for $ovf_path and change its path to where your Windows Server OVF resides
# 4.) Speak with client about IPs and Naming Scheme, the Spreadsheet will need to be filled out to work properly
# 5.) Run Powershell as Administrator
# 6.) Navigate to the path of the script and call it ./"script name"
#################################################################################

#################################################################################
# Set Working Directory
#################################################################################
$csvloc = "C:\Users\Administrator\Desktop\RB-Scripts"
Set-Location $csvloc
 
#################################################################################
# Add PowerCLI Snapins and Ignore Certificate Warnings
#################################################################################
Write-Host "Adding Powershell VMware Snapins!" -ForegroundColor Green
 
Add-PsSnapin VMware.VimAutomation.Core
Add-PsSnapin VMware.VimAutomation.Vds

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false | Out-Null
 
#################################################################################
# Import CSV
#################################################################################
$csv = Import-Csv $csvloc"\post-deploy.csv"

Write-Host "Importing Specified CSV!" -ForegroundColor Green
 
 
foreach ($line in $csv)
{
 
    #################################################################################
    # Set Variables
    #################################################################################
    
    $vmhost_user = "root"
	$vmhost_pass = "vSphereP3"
	$newhost = $line.Host
	$host_IP = $line.IP
	
	$win_user = "Administrator"
	$win_pass = "Pivot3!"
	
	$subnet = $line.Subnet
	$gateway = $line.Gateway

	$ntp = $line.NTP
	$dns1 = $line.DNS1
	$dns2 = $line.DNS2
	
	$datastore = $line.Datastore
	$VMName = $line.VMName
	$pkey = $line.ProductKey
	
Write-Host "Starting Script!" -ForegroundColor Green
    
#################################################################################
# Connect to Hosts
#################################################################################
Write-Host "Connecting to $newhost ESXi Host!" -ForegroundColor Green
    
Connect-VIServer $newhost -User $vmhost_user -Password $vmhost_pass | Out-Null

#################################################################################
# Update VM Tools
#################################################################################

Update-Tools $VMname

#################################################################################
# Change Names of Windows VMs
#################################################################################

$Win_Name = "Rename-Computer RB-REC-01"
Invoke-VMScript -ScriptText $Win_Name -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#################################################################################
# Change Timezone and Time of Windows VMs
#################################################################################

# Timezone Options include: Pacific Standard Time, Central Standard Time, Eastern Standard Time etc.
$Win_TZ = 'tzutil.exe /s "Pacific Standard Time"'
$Win_Time = 'Set-Date "07/20/2017 12:00 PM"'

Invoke-VMScript -ScriptText $Win_TZ -VM $VMName -GuestUser $win_user -GuestPassword $win_pass
Invoke-VMScript -ScriptText $Win_Time -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#################################################################################
# Set Windows Licensing
#################################################################################

$unset_lic = "slmgr -upk"
$set_lic = 'slmgr -ipk "00000-00000-00000-00000-00000"'
$active = 'slmgr /ato'

Invoke-VMScript -ScriptText $unset_lic -VM $VMName -GuestUser $win_user -GuestPassword $win_pass
Invoke-VMScript -ScriptText $set_lic -VM $VMName -GuestUser $win_user -GuestPassword $win_pass
Invoke-VMScript -ScriptText $active -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#################################################################################
# Disable Windows Search Service
#################################################################################

$disable_ss = 'sc config WSearch start= disabled'

Invoke-VMScript -ScriptText $disable_ss -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#####################################################################################
# Set Networks to Correct Portgroup and Make sure Connected and Connected at Startup
#####################################################################################

Write-Host "Setting VM Network!" -ForegroundColor Yellow
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup "VM Network" -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -StartConnected:$true -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Connected:$true -confirm:$false | Out-Null
Write-Host "Set Complete!" -ForegroundColor Green

Write-Host "Setting SAN0 Network!" -ForegroundColor Yellow
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -Portgroup "SAN Network 0" -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -StartConnected:$true -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -Connected:$true -confirm:$false | Out-Null
Write-Host "Set Complete!" -ForegroundColor Green

Write-Host "Setting SAN1 Network!" -ForegroundColor Yellow
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 3" | Set-NetworkAdapter -Portgroup "SAN Network 1" -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 3" | Set-NetworkAdapter -StartConnected:$true -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 3" | Set-NetworkAdapter -Connected:$true -confirm:$false | Out-Null
Write-Host "Set Complete!" -ForegroundColor Green

Write-Host "Setting Camera Network!" -ForegroundColor Yellow
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 4" | Set-NetworkAdapter -Portgroup "Camera Network" -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 4" | Set-NetworkAdapter -StartConnected:$true -confirm:$false | Out-Null
Get-VM RB-REC-01 | Get-NetworkAdapter -Name "Network adapter 4" | Set-NetworkAdapter -Connected:$true -confirm:$false | Out-Null
Write-Host "Set Complete!" -ForegroundColor Green


#################################################################################
# Map the Network Adapter in VMware and Windows and Rename Accordingly
#################################################################################

#Just for clarity, this will show all of the PCISlot information for NICs

$code = @'
Get-NetAdapterHardwareInfo |
select name,slot,@{N='mac';E={Get-NetAdapter -Name $_.Name | select -ExpandProperty MacAddress}} |
ConvertTo-Csv -UseCulture -NoTypeInformation
'@
 
Get-VM |
where{$_.PowerState -eq 'PoweredOn' -and $_.ExtensionData.COnfig.GuestFullName -match 'Windows'} | %{
    $osPCI = Invoke-VMScript -VM $_ -ScriptText $code -ScriptType Powershell -GuestUser Administrator -GuestPassword Pivot3! |
        Select -ExpandProperty ScriptOutput | ConvertFrom-Csv
    foreach($vnic in Get-NetworkAdapter -VM $_){
        $osNic = $osPCI | where{$_.slot -eq $vnic.ExtensionData.SlotINfo.PciSlotNumber}
        New-Object PSObject -Property ([ordered]@{
            VM = $_.Name
            Portgroup = $vnic.NetworkName
            vMAC = $vnic.MacAddress
            osMAC = $osNic.mac
            vNIC = $vnic.Name
            osNIC = $osNic.name
            vSlot = $vnic.ExtensionData.SlotINfo.PciSlotNumber
            osSlot = $osNic.Slot
        })
    }
}

# This piece will actually map and change the Adapters in Windows to match VMware Portgroups

$code = @'
Get-NetAdapterHardwareInfo |
select name,slot,@{N='mac';E={Get-NetAdapter -Name $_.Name | select -ExpandProperty MacAddress}} |
ConvertTo-Csv -UseCulture -NoTypeInformation
'@
$changeAdapterName = @'
Rename-NetAdapter -Name '#oldname#' -NewName '#newname#' -Confirm:$false
'@
 
Get-VM |
where{$_.PowerState -eq 'PoweredOn' -and $_.ExtensionData.COnfig.GuestFullName -match 'Windows'} | %{
    $osPCI = Invoke-VMScript -VM $_ -ScriptText $code -ScriptType Powershell -GuestUser Administrator -GuestPassword Pivot3! |
        Select -ExpandProperty ScriptOutput | ConvertFrom-Csv
    foreach($vnic in Get-NetworkAdapter -VM $_){
        $osNic = $osPCI | where{$_.slot -eq $vnic.ExtensionData.SlotINfo.PciSlotNumber}
        if($osNic){
            if($osNic.Name -ne $vnic.NetworkName){
                $codeAdapter = $changeAdapterName.Replace('#oldname#',$osNic.Name).Replace('#newname#',$vnic.NetworkName)
                Invoke-VMScript -VM $_ -ScriptText $codeAdapter -ScriptType Powershell -GuestUser Administrator -GuestPassword Pivot3!
            }
        }
    }
}


#################################################################################
# Change IPs on Windows VM Network Adapters
#################################################################################

$set_ip = '
netsh interface ip set address "VM Network" static 192.168.0.112 255.255.255.0 192.168.0.1
netsh interface ipv4 add dnsservers name="VM Network" 192.168.0.100  index=1
netsh interface ipv4 add dnsservers name="VM Network" 192.168.0.101 index=2
netsh interface ip set address "SAN Network 0" static 192.168.0.12 255.255.255.0
netsh interface ipv4 add dnsservers name="SAN Network 0" 192.168.0.100 index=1
netsh interface ipv4 add dnsservers name="SAN Network 0" 192.168.0.101 index=2
netsh interface ip set address "SAN Network 1" static 192.168.1.12 255.255.255.0
netsh interface ipv4 add dnsservers name="SAN Network 1" 192.168.0.100 index=1
netsh interface ipv4 add dnsservers name="SAN Network 1" 192.168.0.101 index=2
netsh interface ip set address "Camera Network" static 192.168.0.113 255.255.255.0 192.168.0.1
netsh interface ipv4 add dnsservers name="Camera Network" 192.168.0.100 index=1
netsh interface ipv4 add dnsservers name="Camera Network" 192.168.0.101 index=2
'
Invoke-VMScript -ScriptText $set_ip -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#################################################################################
# Set Camera NIC Best Practice Settings (RX Ring / Small RX Buffer)
#################################################################################

$cam_nic_config ='
Set-NetAdapterAdvancedProperty "Camera Network" -DisplayName "Rx Ring #1 Size" -DisplayValue 4096
Set-NetAdapterAdvancedProperty "Camera Network" -DisplayName "Small Rx Buffers" -DisplayValue 8192'

Invoke-VMScript -ScriptText $cam_nic_config -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

#################################################################################
# Configure iSCSI Initator and Instantiate Volume in RAIGE CLI
#################################################################################

$config_raige_init = '
$rloc = "C:\Program Files\Pivot3\RAIGE Connection Manager"
Set-Location $rloc
.\p3rcmcli.exe
config initiator name RB-REC-01
cin rb-rec-01
cdar RB-vPG
ct* 
'
Invoke-VMScript -ScriptText $config_raige_init -VM $VMName -GuestUser $win_user -GuestPassword $win_pass


#################################################################################
# Initialize,Online and Configure Drive in Windows OS
#################################################################################

$pdisk ='
Initialize-Disk 1 
New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter | Format-Volume -NewFileSystemLabel "RB-REC-02" -FileSystem NTFS -AllocationUnitSize 65536 -confirm:$false
fsutil fsinfo ntfsinfo E:
'
Invoke-VMScript -ScriptText $pdisk -VM $VMName -GuestUser $win_user -GuestPassword $win_pass

	
#################################################################################
# Disconnect Each Host After Configuration
#################################################################################

Disconnect-VIServer * -Verbose -confirm:$false
   
}
