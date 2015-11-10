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
# Installation Procedure: https://my.inin.com/products/cic/Documentation/mergedProjects/wh_tr/bin/web_portal_marquee_icg.pdf
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
  #$latestpatch                      = 'Patch2'
  $webapplicationszip               = "CIC_Web_Applications_${::cic_installed_major_version}_R${::cic_installed_release}.zip"

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
      # ====================
      # -= Media Services =-
      # ====================

      # Download WebPI Command Line
      exec {'Download WebPI Command Line':
        command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('http://go.microsoft.com/fwlink/?LinkId=209681','${cache_dir}/webpicmd_x86.zip')",
        path     => $::path,
        cwd      => $::system32,
        timeout  => 900,
        provider => powershell,
      }

      # Unzip WebPI Command Line
      unzip {'Unzip WebPI Command Line':
        name        => "${cache_dir}/webpicmd_x86.zip",
        destination => "${cache_dir}/IWP",
        creates     => "${cache_dir}/IWP/WebpiCmdLine.exe",
        require     => Exec['Download WebPI Command Line'],
      }

      # Install Media Services
      exec {'Install Media Services':
        command  => "cmd /c '${cache_dir}/IWP/WebPiCmdLine.exe /Products:MediaServices /AcceptEula'",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => Unzip['Unzip WebPI Command Line'],
      }

      # =================
      # -= Silverlight =-
      # =================

      # Download Microsoft Silverlight (Silverlight.exe)
      exec {'Download Microsoft Silverlight':
        command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('http://silverlight.dlservice.microsoft.com/download/8/E/7/8E7D9B4B-2088-4AED-8356-20E65BE3EC91/40728.00/Silverlight.exe','${cache_dir}/Silverlight.exe')",
        path     => $::path,
        cwd      => $::system32,
        timeout  => 900,
        provider => powershell,
      }

      # Install Microsoft Silverlight
      package {'Install Microsoft Silverlight':
        ensure          => installed,
        source          => "${cache_dir}/Silverlight.exe",
        install_options => [
          '/l*v',
          'c:\\windows\\logs\\silverlight.log',
        ],
        provider        => 'windows',
        require         => Exec['Download Microsoft Silverlight'],
      }

      # Add WCF (Server Manager/Features/.Net 3.5.1 Features/WCF Activation). Already done?

      # ============
      # -= AD LDS =-
      # ============

      # Install LDS role in Windows (ADLDS)
      /*
      core::windows::feature { 'ADLDS':
        ensure  => present,
        restart => false,
      }
      */

      # Install Active Directory Lightweight Directory Services (LDS). CANNOT BE AUTOMATED. USE AUTOHOTKEY?
      exec {'Install Lightweight Directory Services':
        command => "cmd.exe /c C:\\I3\\IC\\Install\\ExternalInstalls\\IWebPortal\\ININ.IWP.LDSConfig.exe",
        path    => $::path,
        cwd     => $::system32,
        timeout => 30,
        require => [
          Exec['Install Microsoft Silverlight'],
          Exec['Install Media Services'],
        ],
      }

      # ====================================
      # -= Install Interaction Web Portal =-
      # ====================================

      exec {'Mount CIC iso':
        command => "cmd.exe /c imdisk -a -f \"${daascache}\\CIC_${::cic_installed_major_version}_R${::cic_installed_release}.iso\" -m l:",
        path    => $::path,
        cwd     => $::system32,
        creates => 'l:/Installs/Install.exe',
        timeout => 30,
      }

      # TODO Says that WCF is STILL NOT INSTALLED
      # Install Interaction Web Portal
      package {'Install Interaction Web Portal':
        ensure          => installed,
        source          => "L:/Installs/Off-ServerComponents/InteractionWebPortal_${::cic_installed_major_version}_R${::cic_installed_release}.msi",
        install_options => [
          '/l*v',
          'c:\\windows\\logs\\mediaserver.log',
          {'INTERACTIVEINTELLIGENCE'=>'C:\\Program Files (x86)\\Interactive Intelligence\\'},
          {'PROMPTEDPASSWORD'=>'vagrant'},
          {'STARTEDBYEXEORIUPDATE'=>'1'},
          {'REBOOT'=>'ReallySuppress'}
        ],
        provider        => 'windows',
        require         => [
          Exec['Mount CIC iso'],
          Exec['Install Lightweight Directory Services'],
        ],
      }

      # Unmount CIC
      exec {'Unmount CIC iso':
        command => 'cmd.exe /c imdisk -D -m w:',
        path    => $::path,
        cwd     => $::system32,
        timeout => 30,
        require => Package['Install Interaction Web Portal'],
      }

      # ==============================
      # -= Create ININApps web site =-
      # ==============================

      # Create application pool (disable .Net runtime)
      exec{'Add ININApps App Pool':
        command => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd add apppool /name:ININApps /managedRRuntimeVersion:\"",
        path    => $::path,
        cwd     => $::system32,
        unless  => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd list apppool | findstr /l ININApps\"",
        require => Exec['Install Media Services'],
      }

      # Create a new site called ININApps
      exec {'Add ININApps Virtual Directory':
        command => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd add vdir /app.name:ININApps / /path:/ININApps /physicalPath:c:\\inetpub\\wwwroot\\ININApps\"",
        path    => $::path,
        cwd     => $::system32,
        unless  => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd list vdir | findstr /l ININApps\"",
        require => Exec['Add ININApps App Pool'],
      }

      # Create virtual application
      iis_app {'ININApps/':
        ensure          => present,
        applicationpool => 'ININApps',
        require         => Iis_Site['ININApps'],
      }

      # TODO: TO COMPLETE (create virtual application using appcmd)

      # Add Desktop Experience feature in Windows

      # Add CIC server in Interaction Web Portal configuration

      # Reboot
    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}
