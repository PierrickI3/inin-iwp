define core::windows::feature(
  $ensure           = installed,
  $restart          = true,
  $subfeatures      = false,
  $management_tools = false,
  $timeout          = 300,
)
{
  validate_re($ensure, ['^(present|installed|absent|uninstalled)$'])

  if (is_array($name))
  {
    $feature_name = join($name, ',')
  }
  else
  {
    $feature_name = $name
  }

  case $::operatingsystemrelease
  {
    '6.1.7601', '2008 R2' : # Windows 7, 2008R2
    {
      case $ensure
      {
        'present', 'installed':
        {
          $subfeatures_option = $subfeatures ? { true => '-IncludeAllSubFeature',   default => '' }
          if ($management_tools)
          {
            warn('Automatic inclusion of Management tools is not supported on Windows 7 and 2008 R2')
          }

          if ($restart)
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Add-WindowsFeature -Name ${feature_name} ${subfeatures_option}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.Installed -eq \$true}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              notify   => Reboot['now'],
              require  => Exec['chocolatey-install'],
            }
          }
          else
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Add-WindowsFeature -Name ${feature_name} ${subfeatures_option}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.Installed -eq \$true}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              require  => Exec['chocolatey-install'],
            }
          }
        }
        'absent', 'uninstalled':
        {
          if ($restart)
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Remove-WindowsFeature -Name ${feature_name}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.Installed -eq \$false}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              notify   => Reboot['now'],
              require  => Exec['chocolatey-install'],
            }
          }
          else
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Remove-WindowsFeature -Name ${feature_name}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.Installed -eq \$false}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              require  => Exec['chocolatey-install'],
            }
          }
        }
        default: { fail("Unsupported ensure parameter: ${ensure}") }
      }
    }
    default:      # Windows 8, 8.1, 2012, 2012R2
    {
      case $ensure
      {
        'present', 'installed':
        {
          $subfeatures_option = $subfeatures      ? { true => '-IncludeAllSubFeature',   default => '' }
          $tools_option       = $management_tools ? { true => '-IncludeManagementTools', default => '' }

          if ($restart)
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Install-WindowsFeature -Name ${feature_name} ${subfeatures_option} ${tools_option}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.InstallState -eq 'Installed'}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              notify   => Reboot['now'],
            }
          }
          else
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Install-WindowsFeature -Name ${feature_name} ${subfeatures_option} ${tools_option}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.InstallState -eq 'Installed'}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
            }
          }
        }
        'absent', 'uninstalled':
        {
          if ($restart)
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Uninstall-WindowsFeature -Name ${feature_name}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.InstallState -ne 'Installed'}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
              notify   => Reboot['now'],
            }
          }
          else
          {
            exec {"core-windows-feature-${feature_name}":
              command  => "Uninstall-WindowsFeature -Name ${feature_name}",
              onlyif   => "if ((Get-WindowsFeature ${feature_name}) | where { \$_.InstallState -ne 'Installed'}) { exit 1 }",
              provider => powershell,
              timeout  => $timeout,
            }
          }
        }
        default: { fail("Unsupported ensure parameter: ${ensure}") }
      }
    }
  }
}

include pget
include unzip

# == Class: iwp::install
#
# Installs and configures Interaction Web Portal.
#
# === Parameters
#
# [ensure]
#   installed. No other values are currently supported.
#
# === Examples
#
#  class {'iwp=::install':
#   ensure => installed,
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015, Interactive Intelligence Inc.
#

class iwp::install (
  $ensure = installed,
)
{

  $daascache                        = 'C:/daas-cache/'
  $currentversion                   = '2015_R3'
  $latestpatch                      = 'Patch8'

  $webapplicationszip               = "CIC_Web_Applications_${currentversion}.zip"
  $webapplicationslatestpatchzip    = "CIC_Web_Applications_${currentversion}_${latestpatch}.zip"
  
  $server                           = $::hostname
  
  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  case $ensure
  {
    installed:
    {
      
      # Download IIS Media Services
      pget {'Download IIS Media Services':
        source => 'https://www.microsoft.com/web/handlers/webpi.ashx?command=getinstaller&appid=MediaServices',
        target => $cache_dir,
      }

      # Download Microsoft Silverlight
      pget {'Download Microsoft Silverlight':
        source => 'http://silverlight.dlservice.microsoft.com/download/8/E/7/8E7D9B4B-2088-4AED-8356-20E65BE3EC91/40728.00/Silverlight.exe',
        target => $cache_dir,
      }

      # Add "Application Development" to IIS (already done by default?)

      # Add WCF (Server Manager/Features/.Net 3.5.1 Features/WCF Activation)

      # Install Media Services

      # Install Lightweight Directory Services (LDS) Role (\\CICSERVER\IC_WorkstationPreReqs\IWebPortal\ININ.IWP.LdsConfig.exe)
      #   First Instance
      #   LDS Administrator (vagrant?)

      # Install Scheduled Reports Monitor server (?)

      # Create a web site in IIS

      # Add Desktop Experience feature in Windows

      # Install Interaction Web Portal (InteractionWebPortal_2015Rx.msi)
      #    Use web site created previously
      
      # Add CIC server in Interaction Web Portal configuration

    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}