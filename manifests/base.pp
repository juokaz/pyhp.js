node default {
    # this makes puppet and vagrant shut up about the puppet group
    group { "puppet":
        ensure => "present",
    }

    # Set default paths
    Exec { path => '/usr/bin:/bin:/usr/sbin:/sbin' }

    # make sure the packages are up to date before beginning
        exec { "apt-get update":
        command => "apt-get update"
    }

    # because puppet command are not run sequentially, ensure that packages are
    # up to date before installing before installing packages, services, files, etc.
    Package { require => Exec["apt-get update"] }
    File { require => Exec["apt-get update"] }

    package {
        "build-essential": ensure => installed;
        "python": ensure => installed;
        "python-dev": ensure => installed;
        "python-pip": ensure => installed;
    }

    package {
        "libffi-dev": ensure => installed;
        "git": ensure => installed;
        "cmake": ensure => installed;
        "emscripten": ensure => installed;
    }

    exec{ "retrieve_pypy":
        command => "/usr/bin/wget -q https://bitbucket.org/pypy/pypy/downloads/pypy-2.5.1-linux.tar.bz2 -O /home/vagrant/pypy.tar.bz2",
        creates => "/home/vagrant/pypy.tar.bz2",
    }

    file { "/home/vagrant/pypy":
        ensure => "directory",
        mode => 777,
    }

    exec { "extract_pypy":
        command => "tar xfv pypy.tar.bz2 -C pypy --strip-components 1",
        cwd => "/home/vagrant",
        creates => "/home/vagrant/pypy/bin",
        require => [File["/home/vagrant/pypy"], Exec["retrieve_pypy"]]
    }

    file { '/usr/local/bin/pypy':
        ensure => 'link',
        target => '/home/vagrant/pypy/bin/pypy',
        require => Exec["extract_pypy"]
    }

    file {  "/home/vagrant/pypyjs/rpython/_cache":
        ensure => "directory",
        mode => 777,
        require => Exec["retrieve_pypyjs"]
    }

    exec { "retrieve_pypyjs":
        command => "git clone https://github.com/rfk/pypy.git /home/vagrant/pypyjs",
        creates => "/home/vagrant/pypyjs/rpython/bin/rpython",
        require => Package["git"]
    }

    file { '/usr/local/bin/rpython':
        ensure => 'link',
        target => '/home/vagrant/pypyjs/rpython/bin/rpython',
        require => Exec["retrieve_pypyjs"]
    }

    exec { "create_socket_patch":
        command => "grep -v 'AF_NETLINK' /usr/share/emscripten/system/include/libc/sys/socket.h > /tmp/socket.h.new",
        creates => "/tmp/socket.h.new",
        require => Package["emscripten"]
    }

    file { "/usr/share/emscripten/system/include/libc/sys/socket.h":
        ensure => present,
        source => "/tmp/socket.h.new",
        require => Exec["create_socket_patch"]
    }

    exec { "retrieve_pyhp":
        command => "git clone https://github.com/juokaz/pyhp.git /var/www/pyhp.js/pyhp",
        creates => "/var/www/pyhp.js/pyhp",
        require => Package["git"]
    }
}
