#################################################################################
# @-Roy Berkowitz 2017-@
# Instructions:
# 1.) Download this RACADM utility from Dell : http://www.dell.com/support/home/ca/en/cabsdt1/Drivers/DriversDetails?driverId=HR1V5
# 2.) Unzip and install the RAC executable and its placed in Program Files \ Dell \ SysMgmt \ racadm.exe
# 3.) Set laptop IP address on the 192.168.0.x network to reach default iDRAC
# 4.) Connect laptop to iDRAC port on back of Appliance (make sure iDRAC can be reached)
# 5.) Set variables below according to Engagement iDRAC IPs and Naming Scheme
# 6.) Open Powershell as Administrator (not required but good to do)
# 7.) Navigate to path of this script: config-drac.ps1
# 8.) Once at path, run the script with: .\config-drac.ps1
#
#	TO DO: Implement iDRAC config into CSV as to not change variables in the script
#
#  4 Min per server until I can script a for loop and use variables
#################################################################################


<#################################################################################
# Set Working Directory
#################################################################################
$csvloc = "C:\Users\rberkowitz\Desktop\Stuff\Scripts"
Set-Location $csvloc

#################################################################################
# Import CSV
#################################################################################
$csv = Import-Csv $csvloc"\post-deploy.xlsx"
Write-Host "Importing Specified CSV!" -ForegroundColor Green
#>
#################################################################################
# Set Variables
#################################################################################
    <#    
    $iDrac_User = "root"
	$iDrac_Pass = "calvin"
	$iDRAC_Name = $line.iDRAC_Name
	$iDRAC_def_IP = $line.iDRAC_def_IP
	$iDRAC_new_IP = $line.iDRAC_new_IP
	$iDRAC_Netmask = $line.iDRAC_Netmask
	$iDRAC_Gateway = $line.iDRAC_Gateway
	$iDRAC_DNS1 = $line.iDRAC_DNS1
	$iDRAC_DNS2 = $line.iDRAC_DNS2
	#>
	
	$iDrac_User = "root"  				# This doesnt change #
	$iDrac_Pass = "calvin" 				# This doesnt change #
	$iDRAC_Name = "rbt2"
	$iDRAC_def_IP = "192.168.0.120" 	# This doesnt change #
	$iDRAC_new_IP = "192.168.0.2"
	$iDRAC_Netmask = "255.255.255.0"
	$iDRAC_Gateway = "192.168.0.1"
	$iDRAC_DNS1 = "192.168.0.100"
	$iDRAC_DNS2 = "192.168.0.101"
	
Write-Host "Starting Script!" -ForegroundColor Green

#################################################################################
# Configure the following for iDRAC:
#		Name
#		IP
#		Netmask
#		Gateway
#		DNS1
#		DNS2
#################################################################################

# & 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass racresetcfg

& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_def_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.NIC.DNSRacName $iDRAC_Name
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_def_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.IPv4.Address $iDRAC_new_IP
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.IPv4.Netmask $iDRAC_Netmask
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.IPv4.Gateway $iDRAC_Gateway
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.IPv4.DNS1 $iDRAC_DNS1
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.IPv4.DNS2 $iDRAC_DNS2
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass set iDRAC.Tuning.DefaultCredentialWarning Disabled
 
#################################################################################
# Power Up Appliance
################################################################################# 
 
& 'C:\Program Files (x86)\Dell\SysMgt\rac5\racadm.exe' -r $iDRAC_new_IP -u $iDRAC_User -p $iDRAC_Pass serveraction powerup