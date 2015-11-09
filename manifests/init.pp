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
  $currentversion                   = '2016_R1'
  $latestpatch                      = ''

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
      # ====================
      # -= Media Services =-
      # ====================

      # Download WebPI Command Line (webpicmd_x86.zip)
      pget {'Download WebPI Command Line':
        source => 'http://go.microsoft.com/fwlink/?LinkId=209681',
        target => $cache_dir,
      }

      # Unzip WebPI Command Line
      unzip {'Unzip WebPI Command Line':
        name        => "${daascache}webpicmd_x86.zip",
        destination => "${cache_dir}/IWP",
        creates     => "${cache_dir}/IWP/WebpiCmdLine.exe",
        require     => Pget['Download WebPI Command Line'],
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
      pget {'Download Microsoft Silverlight':
        source => 'http://silverlight.dlservice.microsoft.com/download/8/E/7/8E7D9B4B-2088-4AED-8356-20E65BE3EC91/40728.00/Silverlight.exe',
        target => $cache_dir,
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
        require         => Pget['Download Microsoft Silverlight'],
      }

      # Add WCF (Server Manager/Features/.Net 3.5.1 Features/WCF Activation). Already done?

      # =========
      # -= LDS =-
      # =========

      # Install LDS role in Windows (ADLDS)
      core::windows::feature { 'ADLDS':
        ensure  => present,
        restart => false,
      }

      # Install Lightweight Directory Services (LDS) Role (\\CICSERVER\IC_WorkstationPreReqs\IWebPortal\ININ.IWP.LdsConfig.exe)
      #   First Instance
      #   LDS Administrator (vagrant?)
      #package {'Install Lightweight Directory Services':
      #  ensure          => installed,
      #  source          => 'C:/I3/IC/Install/ExternalInstalls/IWebPortal/ININ.IWP.LDSConfig.exe',
      #  install_options => [
      #    '/l*v',
      #    'c:\\windows\\logs\\ININ.IWP.LDSConfig.log',
      #  ],
      #  provider        => 'windows',
      #  require         => Core::Windows::Feature['ADLDS'],
      #}

      # Enable IIS
      class {'installiis':
        ensure  => installed,
        restart => false,
      }

      # ====================================
      # -= Install Interaction Web Portal =-
      # ====================================

      # Mount Windows 2012R2 ISO
      exec {'mount-windows-2012R2-iso':
        command => "cmd.exe /c imdisk -a -f \"${daascache}\\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_ENTERPRISE_EVAL_EN-US-IR3_CENA_X64FREE_EN-US_DV9.iso\" -m w:",
        path    => $::path,
        cwd     => $::system32,
        creates => 'w:/setup.exe',
        timeout => 30,
        require => Class['installiis'],
      }

      # Install Interaction Web Portal TODO =====> Says that WCF is STILL NOT INSTALL
      package {'install-interaction-web-portal':
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
        require         => Exec['mount-cic-iso'],
      }

      # Unmount Windows 2012R2 ISO
      exec {'unmount-cic-iso':
        command => 'cmd.exe /c imdisk -D -m w:',
        path    => $::path,
        cwd     => $::system32,
        timeout => 30,
        require => Package['install-interaction-web-portal'],
      }

      # ==============================
      # -= Create a web site in IIS =-
      # ==============================

      # Remove Default Web Site
      iis_site {'Default Web Site':
        ensure  => absent,
        require => Class['installiis'],
      }

      # Create application pool (disable .Net runtime)
      iis_apppool {'ININApps':
        ensure                => present,
        managedruntimeversion => '',
        require               => [
          Exec['Install Media Services'],
          Iis_site['Default Web Site'],
        ],
      }

      # Create a new site called ININApps
      iis_site {'ININApps':
        ensure   => present,
        bindings => ['http/*:80:'],
        require  => Iis_Apppool['ININApps'],
      }

      # Create virtual application
      iis_app {'ININApps/':
        ensure          => present,
        applicationpool => 'ININApps',
        require         => Iis_Site['ININApps'],
      }

      # Create virtual directory
      iis_vdir {'ININApps/':
        ensure       => present,
        iis_app      => 'ININApps/',
        physicalpath => 'C:\inetpub\wwwroot\ININApps',
        require      => Iis_App['ININApps/'],
      }


      # Add Desktop Experience feature in Windows

      #    Use web site created previously

      # Add CIC server in Interaction Web Portal configuration

      # Reboot

    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}
