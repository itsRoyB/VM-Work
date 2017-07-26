#################################################################################
# @-Roy Berkowitz 2017-@
# Instructions:
# 1.) Place the CSV file named 'post-deploy.csv' and this script (p3-deploy-auto.ps1) into a folder of your choosing (Same as config-idrac) 
# 2.) Wherever you place the CSV, change the variable below $csvloc to that path
# 3.) Find the Variable for $ovf_path and change its path to where your Windows Server OVF resides
# 4.) Check to make sure that variable $p3loc has the correct path for your Pivot3 Installation
# 5.) Make sure that the P3_Script.txt is in the Pivot3 Installation folder: C:\Program Files (x86)\Pivot3\vSTAC Manager Suite

#	** IMPORTANT! **
#	You need to alter the variables inside the P3_Script.txt in order to have this work!
#	Read the README file included for settings!
#	** IMPORTANT! **

# 6.) Speak with client about IPs and Naming Scheme, the Spreadsheet will need to be filled out to work properly
# 7.) Run Powershell as Administrator (not required but good to do)
# 8.) Navigate to the path of the script and run it:  .\p3-deploy-auto.ps1

# 1:50m until OVF deploy 
#################################################################################

#################################################################################
# Set Working Directory
#################################################################################
$csvloc = "C:\Users\rberkowitz\Desktop\Stuff\Scripts"
$p3loc = "C:\Program Files (x86)\Pivot3\vSTAC Manager Suite"
Set-Location $csvloc
 
#################################################################################
# Add PowerCLI Snapins and Ignore Certificate Warnings
#################################################################################
Write-Host "Adding Powershell VMware Snapins!" -ForegroundColor Green
 
# Add-PsSnapin 
Import-Module VMware.VimAutomation.Core
# Add-PsSnapin 
Import-Module VMware.VimAutomation.Vds

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
	
	$san0vmk = $line.SAN0vmk
	$san1vmk = $line.SAN1vmk
	
	$ntp = $line.NTP
	$dns1 = $line.DNS1
	$dns2 = $line.DNS2
	
	$alias = $line.iSCSIAlias
	
	$subnet = $line.Subnet
	$gateway = $line.Gateway

	
Write-Host "Starting Script!" -ForegroundColor Green

#################################################################################
# Connect to Hosts
#################################################################################
Write-Host "Connecting to $newhost ESXi Host!" -ForegroundColor Green
    
Connect-VIServer $newhost -User $vmhost_user -Password $vmhost_pass | Out-Null
      
#################################################################################
# Get VMKernel PortGroup and Assign IP and Subnet4
#################################################################################
Write-Host "Find the VMKernel PortGroup on Host $newhost and Assign New IP and Subnet to it!" -ForegroundColor Green

$vmkernel0 = Get-VMHostNetworkAdapter | where { $_.PortGroupName -eq "SAN iSCSI VMK 0" } 
Set-VMHostNetworkAdapter -VirtualNIC $vmkernel0 -IP "$san0vmk" -SubnetMask "$subnet" -confirm:$False

##Dont Test With This One##
$vmkernel1 = Get-VMHostNetworkAdapter | where { $_.PortGroupName -eq "SAN iSCSI VMK 1" }
Set-VMHostNetworkAdapter -VirtualNIC $vmkernel1 -IP "$san1vmk" -SubnetMask "$subnet"  -confirm:$False

#################################################################################
# Assign NTP Server Information and Configure NTP Settings
#################################################################################
Write-Host "Configuring NTP and Enabling Auto-Start!" -ForegroundColor Green

Get-VMHost | Add-VMHostNtpServer -NtpServer $ntp | Out-Null
Get-VmHostService | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService | Out-Null
Get-VmHostService | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic" | Out-Null

#################################################################################
# Check NameServer Values and Progress if Valid
################################################################################

Write-Host "Checking NameServer Settings!" -ForegroundColor Green

$dnscheck = Get-VMHostNetwork | Select -ExpandProperty DnsAddress
Write-Host "Below are the currently applied DNS Settings!" -ForegroundColor Yellow
$dnscheck

if ($dnscheck -contains "$dns1" -And $dnscheck -contains "$dns2")
{
Write-Host "DNS Settings are Correct!" -ForegroundColor Yellow
}
else
{
Write-Host "DNS Settings are Incorrect! Setting Correct DNS Entries" -ForegroundColor Yellow

Get-VMHostNetwork | Set-VMHostNetwork -DnsAddress $dns1, $dns2 | Out-Null

Write-Host "DNS Settings are Now Set!" -ForegroundColor Green

}

#################################################################################
# Get APP vSwitch and Rename to Camera
#################################################################################
###  Use At Surveillance Installs###

Write-Host "Rename Default APP Network to Camera Network!" -ForegroundColor Green

$getpg = Get-VirtualPortGroup | where {$_.Name -like "*APP*"} | Select -ExpandProperty Name

if ($getpg -contains "APP Network 0" -And $getpg -contains "APP Network 1")
{
Get-VirtualPortGroup -Name "APP Network 0" | Remove-VirtualPortGroup -confirm:$False | Out-Null
Get-VirtualPortGroup -Name "APP Network 1" | Set-VirtualPortGroup -Name "Camera Network" | Out-Null

####################################################################################
# Note: Assuming a single Camera Network and plugging in on the left port, vmnic5.
####################################################################################

Get-VMHostNetworkAdapter -Physical -Name "vmnic4" | Remove-VirtualSwitchPhysicalNetworkAdapter -confirm:$False | Out-Null
Remove-VirtualSwitch vSwitch4 -confirm:$False | Out-Null
}
else
{
Get-VirtualPortGroup -Name "APP Network 1" | Set-VirtualPortGroup -Name "Camera Network" | Out-Null
}

#################################################################################
# Enable Software iSCSI and  Set Alias
#################################################################################

Write-Host "Settings iSCSI Alias!" -ForegroundColor Green

Write-Host "Settings iSCSI Alias!" -ForegroundColor Yellow
$hostView = Get-VMHost $newhost | Get-View        
$storageSystemView = Get-View $hostView.ConfigManager.StorageSystem
$iscsihba = Get-VMHostHba -VMHost $newhost -Type Iscsi
$storageSystemView.UpdateInternetScsiAlias($iscsihba.Name,$alias) | Out-Null

Write-Host "iSCSI Alias Set Complete!" -ForegroundColor Green

#################################################################################
# Disconnect Each Host After Configuration
#################################################################################

Write-Host "Disconnecting from Current Server - Work Completed!" -ForegroundColor Green

Disconnect-VIServer * -confirm:$false

}

#################################################################################
# P3 VM Configuration
#################################################################################

Set-Location $p3loc

.\p3cli.exe -login pivot3:pivot3 -file P3_Script.txt


# For volume create, see command below to find out appropriate RAID level:
# show storageTier raidLevels vSTACName tierNumber

#################################################################################
# Set Working Directory
#################################################################################
$csvloc = "C:\Users\rberkowitz\Desktop\Stuff\Scripts"
Set-Location $csvloc
 
#################################################################################
# Add PowerCLI Snapins and Ignore Certificate Warnings
#################################################################################
Write-Host "Adding Powershell VMware Snapins!" -ForegroundColor Green
 
# Add-PsSnapin 
Import-Module VMware.VimAutomation.Core
# Add-PsSnapin 
Import-Module VMware.VimAutomation.Vds

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
	
    $vmos_ds = $line.VMOS
	$rec_datastore = $line.Datastore
	$ovf_path = "C:\Users\rberkowitz\Desktop\Stuff\Installation Tools\Pivot3-Server2012R2-05242017a-updated.ova"
	$VMName = $line.VMName
	
Write-Host "Starting Script!" -ForegroundColor Green
    
#################################################################################
# Connect to Hosts
#################################################################################
Write-Host "Connecting to $newhost ESXi Host!" -ForegroundColor Green
    
Connect-VIServer $newhost -User $vmhost_user -Password $vmhost_pass | Out-Null

#################################################################################
# Scan HBA and Add Created Volume!
#################################################################################

Write-Host "Rescan LUNs!" -ForegroundColor Yellow
Get-VMHostStorage -VMHost $newhost -RescanAllHba -RescanVmfs | Out-Null

Write-Host "Rescan Complete!" -ForegroundColor Green

Write-Host "Checking $vmos_ds Datastore!" -ForegroundColor Green

Try
{
Get-Datastore -Name $vmos_ds -ErrorAction Stop

Write-Host "This Datastore already exists!" -ForegroundColor Yellow
}
Catch
{
Write-Host "This Datastore does not already exist!" -ForegroundColor Yellow

$dspath = Get-ScsiLun | where { $_.CanonicalName -like "naa*" }
New-Datastore -Name $vmos_ds -Path $dspath -Vmfs

Write-Host "vmos Datastore Created!" -ForegroundColor Green
}

#################################################################################
# Deploy Windows Server 2012 R2 from OVF
#################################################################################

Write-Host "Deploying VM from OVF!" -ForegroundColor Green

Import-vApp -Source "$ovf_path" -VMHost $newhost -Name $VMName -Datastore $vmos_ds -DiskStorageFormat EagerZeroedThick  | Out-Null

Write-Host "Deploy Completed!" -ForegroundColor Green

#################################################################################
# Upgrade Video Recorder VM Memory to 16gb
#################################################################################

Write-Host "Checking to see if Recording VM is on this Host. If so, Change to 16GB Memory! If not, progress to Next Host!" -ForegroundColor Green

$povm = Get-VM | where {$_.PowerState -eq "PoweredOff"}

#Make sure to check Recorder name in Spreadsheet and compare with lookup here#

if($povm.Name -like "*REC*")
{
Write-Host "Found Recording VM, Change Memory!" -ForegroundColor Yellow

$povm | Set-VM -MemoryGB 16 -confirm:$false | Out-Null

Write-Host "Memory Changed Successfully" -ForegroundColor Green
}

#################################################################################
# Power On Windows Server VM
#################################################################################

Write-Host "Starting VM: $povm !"

Start-VM $povm

#################################################################################
# Configure Auto-Startup for VMs on Hosts
#################################################################################

Write-Host "Enable Host Auto Start Policy!" -ForegroundColor Green
Get-VMHostStartPolicy | Set-VMHostStartPolicy -Enabled $true | Out-Null

Write-Host "Move Windows Servers to AutoStart Policy!" -ForegroundColor Green
$vmstartpolicy = Get-VMStartPolicy -VM "$VMName"
Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder 1 | Out-Null

Write-Host "AutoStart Completed Successfully!" -ForegroundColor Green
      
}
