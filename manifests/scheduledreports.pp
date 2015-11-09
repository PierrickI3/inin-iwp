# =======================
      # -= Scheduled Reports =-
      # =======================

      # Install required Microsoft KBs
      # ==============================

      # The following KBs are required for Scheduled Reports. See https://my.inin.com/products/cic/Documentation/mergedProjects/wh_tr/bin/scheduled_reports_icg.pdf (page 10)

      # Download ClearCompressionFlag.exe
      pget {'Download ClearCompressionFlag.exe':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/clearcompressionflag.exe',
        target => $cache_dir,
      }

      # Run ClearCompressionFlag.exe
      exec {'Run ClearCompressionFlag':
        command  => "cmd /c ${cache_dir}/ClearCompressionFlag.exe",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => Pget['Download ClearCompressionFlag.exe'],
      }

      # Download KB2919442 (required for KB2919355)
      pget {'Download KB2919442':
        source => 'http://download.microsoft.com/download/C/F/8/CF821C31-38C7-4C5C-89BB-B283059269AF/Windows8.1-KB2919442-x64.msu',
        target => $cache_dir,
      }

      # Install KB2919442 (required for KB2919355)
      exec {'Install KB2919442':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2919442-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Run ClearCompressionFlag'],
          Pget['Download KB2919442'],
        ],
      }

      # Download KB2919355
      pget {'Download KB2919355':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2919355-x64.msu',
        target => $cache_dir,
      }

      # Install KB2919355
      exec {'Install KB2919355':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2919355-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2919442'],
          Pget['Download KB2919355'],
        ],
      }

      # Download KB2932046
      pget {'Download KB2932046':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2932046-x64.msu',
        target => $cache_dir,
      }

      # Install KB2932046
      exec {'Install KB2932046':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2932046-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2919355'],
          Pget['Download KB2932046'],
        ],
      }

      # Download KB2959977
      pget {'Download KB2959977':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2959977-x64.msu',
        target => $cache_dir,
      }

      # Install KB2959977
      exec {'Install KB2959977':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2959977-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2932046'],
          Pget['Download KB2959977'],
        ],
      }

      # Download KB2937592
      pget {'Download KB2937592':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2937592-x64.msu',
        target => $cache_dir,
      }

      # Install KB2937592
      exec {'Install KB2937592':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2937592-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2959977'],
          Pget['Download KB2937592'],
        ],
      }

      # Download KB2938439
      pget {'Download KB2938439':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2938439-x64.msu',
        target => $cache_dir,
      }

      # Install KB2938439
      exec {'Install KB2938439':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2938439-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2937592'],
          Pget['Download KB2938439'],
        ],
      }

      # Download KB2934018
      pget {'Download KB2934018':
        source => 'http://download.microsoft.com/download/2/5/6/256CCCFB-5341-4A8D-A277-8A81B21A1E35/Windows8.1-KB2934018-x64.msu',
        target => $cache_dir,
      }

      # Install KB2934018
      exec {'Install KB2934018':
        command  => "cmd /c wusa.exe ${cache_dir}/Windows8.1-KB2934018-x64.msu /quiet /norestart",
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          Exec['Install KB2938439'],
          Pget['Download KB2934018'],
        ],
      }

      # Install Scheduled Reports Server
      # ================================

      # Mount CIC ISO
      exec {'mount-cic-iso':
        command => "cmd.exe /c imdisk -a -f \"${daascache}\\CIC_${::cic_installed_major_version}_R${::cic_installed_release}.iso\" -m l:",
        path    => $::path,
        cwd     => $::system32,
        creates => 'l:/Installs/Install.exe',
        timeout => 30,
        require => Exec['Install KB2934018'],
      }

      # Install Scheduled Reports Monitoring Server (DOES NOT RUN ON CIC SERVER!!)
      package {'install-scheduled-reports-monitoring-server':
        ensure          => installed,
        source          => "L:/Installs/Off-ServerComponents/ScheduledReportsServer_${::cic_installed_major_version}_R${::cic_installed_release}.msi",
        install_options => [
          '/l*v',
          'c:\\windows\\logs\\scheduledreportsmonitoringserver.log',
          {'TRANSFORMS'=>"${cache_dir}\\IntegrationsTransform.mst"},
        ],
        provider        => 'windows',
        require         => [
          Pget['Download Integrations MST Transform File'],
          Exec['mount-cic-iso'],
        ],
      }

      # Unmount CIC ISO
      exec {'unmount-cic-iso':
        command => 'cmd.exe /c imdisk -D -m l:',
        path    => $::path,
        cwd     => $::system32,
        timeout => 30,
        require => Package['install-scheduled-reports-monitoring-server'],
      }