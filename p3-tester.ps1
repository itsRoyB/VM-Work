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
 
# Close all open connections
#Disconnect-VIServer -Server $global:DefaultVIServers -Confirm:$false -Verbose -ErrorAction SilentlyContinue
 
foreach ($line in $csv)
{
 
    #################################################################################
    # Set Variables
    #################################################################################
    
    $vmhost_user = "root"
	$vmhost_pass = "vSphereP3"
	$newhost = $line.Host
	$host_IP = $line.IP
	$san0 = $line.SAN0vmk
	$san1 = $line.SAN1vmk
	$subnet = $line.Subnet
	$gateway = $line.Gateway
	$mgmt = $line.ManagementIP
	$ntp = $line.NTP
	$dns1 = $line.DNS1
	$dns2 = $line.DNS2
	$alias = $line.iSCSIAlias
    $vmos_ds = $line.VMOS
	$datastore = $line.Datastore
	$ovf_path = "C:\Users\rberkowitz\Desktop\RB-Scripts\OVA-2012_R2\Template-2012_R2.ovf"
	$VMName = $line.VMName
	
Write-Host "Starting Script!" -ForegroundColor Green
    
#################################################################################
# Connect to Hosts
#################################################################################
Write-Host "Connecting to $newhost ESXi Host!" -ForegroundColor Green
    
Connect-VIServer $newhost -User $vmhost_user -Password $vmhost_pass | Out-Null
    
#Write-Host "Connected to $($global:DefaultVIServers.Name -join ',')"   

#################################################################################
# Get VMKernel PortGroup and Assign IP and Subnet4
#################################################################################
Write-Host "Find the VMKernel PortGroup on Host $newhost and Assign New IP and Subnet to it!" -ForegroundColor Green

$vmkernel0 = Get-VMHostNetworkAdapter $newhost | where { $_.PortGroupName -eq "SAN iSCSI VMK 0" } 
Set-VMHostNetworkAdapter -VirtualNIC $vmkernel0 -IP "$san0" -SubnetMask "$subnet" -confirm:$False
##Dont Test With This One##
#$vmkernel1 = Get-VMHostNetworkAdapter $newhost | where { $_.PortGroupName -eq "SAN iSCSI VMK 1" }
#Set-VMHostNetworkAdapter -VirtualNIC $vmkernel1 -IP "$san1" -SubnetMask "$subnet"  -confirm:$False

#################################################################################
# Assign NTP Server Information and Configure NTP Settings
#################################################################################
Write-Host "Configuring NTP and Enabling Auto-Start!" -ForegroundColor Green

Get-VMHost $newhost | Add-VMHostNtpServer -NtpServer $ntp | Out-Null
Get-VmHostService -VMHost $newhost | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService | Out-Null
Get-VmHostService -VMHost $newhost | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic" | Out-Null

#################################################################################
# Check NameServer Values and Progress if Valid
################################################################################

Write-Host "Checking NameServer Settings!" -ForegroundColor Green

$dnscheck = Get-VMHostNetwork -VMHost $newhost | Select -ExpandProperty DnsAddress
Write-Host "Below are the currently applied DNS Settings!" -ForegroundColor Yellow
$dnscheck

if ($dnscheck -contains "$dns1" -And $dnscheck -contains "$dns2")
{
Write-Host "DNS Settings are Correct!" -ForegroundColor Yellow
}
else
{
Write-Host "DNS Settings are Incorrect! Setting Correct DNS Entries" -ForegroundColor Yellow

Get-VMHostNetwork -VMHost $newhost | Set-VMHostNetwork -DnsAddress $dns1, $dns2 | Out-Null

Write-Host "DNS Settings are Now Set!" -ForegroundColor Green

}

#################################################################################
# Get APP vSwitch and Rename to Camera
#################################################################################
###  Use At Surveillance Installs###

Write-Host "Rename Default APP Network to Camera Network!" -ForegroundColor Green

$rename_cam = Get-VirtualPortGroup $newhost | where { $_.Name -eq "APP" }
$rename_cam | Set-VirtualPortGroup -Name "Camera Network" | Out-Null


#################################################################################
# Use P3 CLI to Send Commands
#################################################################################







#################################################################################
# Enable Software iSCSI and  Set Alias and Rescan
#################################################################################

Write-Host "Settings iSCSI Alias and Rescanning LUNS!" -ForegroundColor Green

Write-Host "Settings iSCSI Alias!" -ForegroundColor Yellow
$hostView = Get-VMHost $newhost | Get-View        
$storageSystemView = Get-View $hostView.ConfigManager.StorageSystem
$iscsihba = Get-VMHostHba -VMHost $newhost -Type Iscsi
$storageSystemView.UpdateInternetScsiAlias($iscsihba.Name,$alias) | Out-Null

Write-Host "Rescan LUNs!" -ForegroundColor Yellow
Get-VMHostStorage -VMHost $newhost -RescanAllHba -RescanVmfs | Out-Null

Write-Host "iSCSI Alias and Rescan Complete!" -ForegroundColor Green

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

if($povm.Name -like "*REC*")
{
Write-Host "Found Recording VM, Change Memory!" -ForegroundColor Yellow

$povm | Set-VM -MemoryGB 16 -confirm:$false | Out-Null

Write-Host "Memory Changed Successfully" -ForegroundColor Green
}

#################################################################################
# Power On Windows Server VM
#################################################################################

Write-Host "Starting VM: $povm!" -ForegroundColor Green
Start-VM -VM $povm

#Wait
#################################################################################
# Upgrade VMTools on Windows Server VM
#################################################################################

#################################################################################
# Change IPs on Windows VM Network Adapters
#################################################################################

#$NetworkSettings = 'netsh interface ip set address "Ethernet0" static x.x.x.x 255.255.255.0 x.x.x.x'

#Invoke-VMScript -ScriptText $NetworkSettings -VM $VMName -GuestCredential $DCLocalCredentia

#################################################################################
# Configure Auto-Startup for VMs on Hosts
#################################################################################

Write-Host "Enable Host Auto Start Policy!" -ForegroundColor Green
Get-VMHostStartPolicy -VMHost $newhost | Set-VMHostStartPolicy -Enabled $true | Out-Null

Write-Host "Move Windows Servers to AutoStart Policy!" -ForegroundColor Green
$vmstartpolicy = Get-VMStartPolicy -VM "$VMName"
Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder 1 | Out-Null

Write-Host "AutoStart Completed Successfully!" -ForegroundColor Green


#################################################################################
# Set Windows Licensing
#################################################################################
    
#################################################################################
# Disconnect Each Host After Configuration
#################################################################################

Disconnect-VIServer * -Verbose -confirm:$false
   
}
