#!/usr/bin/perl
#
#  convert ansible "setup" facts into a mediawiki page
#
#
#
#  TODO:
#
#    - show debug info when flag is set
#    - handle errors 
#      - server not in ansible inventory
#      - python-simplejson not installed
#      - root can't connect
#      - specified user can't connect
#      - specified user can't sudo w/o password
#    - hide "phys" cores when server is a VM
#
#        harder:
#    - map hostname from /etc/hosts to each iface's IP
#      see:  >>> print socket.gethostbyaddr("128.91.127.132")
#                ('baxter.med.upenn.edu', ['baxter'], ['128.91.127.132'])
#
#    - yum repo info 
#    - get info about memory modules
#    - fix debian version info
#
#
#  DONE:
#    - choice to run as user + sudo OR directly as root
#
#  Requires:  
#    - ansible on system running this script
#    - host configured in ansible inventory  /etc/ansible/hosts
#    -  "yum install python-simplejson"  for EL5 systems 
#   
#   
#    example:   ansible  r25db -u root -m raw -a 'yum -y install python-simplejson'



use JSON;
use POSIX;
use Data::Dumper;

use Socket;


use Getopt::Long;


my $server = '';    # format output to be more grep-able
my $user =  '';     # user w/ nopasswd sudo on server
my $debug =  '';    # show lots of data
my $help = '';      # show help text
GetOptions ('debug' => \$debug, 'help' => \$help, 'user=s' => \$user);


($help) && usage ();

#
# Process arguments
#
my $numargs = scalar @ARGV;
($numargs != 1 ) && usage();
my $server = $ARGV[0];


sub usage {
 die "
 Usage:

 $0 [--help] [--debug] [--user user] server

 By default, this script tells ansible to connect as root to the server.

 If you prefer to use a non-root user with passwordless sudo privs, specify it with --user.

 \n\n";
};



#$json = '{"a":1,"b":2,"c":3,"d":4,"e":5}';
#$text = decode_json($json);

my $ansible_json;

if ( $user ne '') {
    # requires passwordless sudo to root
    # DEBUG
    #print "CONNECTING as user: $user \n";
    $ansible_json = `ansible -s -u $user -m setup $server`;
} else {
    # requires direct root ssh access
    # DEBUG
    #print "CONNECTING as user: root \n";
    $ansible_json = `ansible -u root -m setup $server`;
}
#print  Dumper($ansible_json);


$ansible_json =~ s/^.*>>//;

#print "************************************************************\n";

my $ansible_data = decode_json($ansible_json);

#for my $k (sort keys $ansible_data) {
#  print " - $k \n";
#}

# DEBUG
#for my $k (sort keys $ansible_data->{'ansible_facts'}) {
#  print " - $k \n";
#}

my $facts = $ansible_data->{'ansible_facts'};

# DEBUG 
#print  Dumper($facts);


#print "************************************************************\n";


#
#if ( ${ansible_data->{'changed'}} ) {
#  print "TRUE \n";
#} else {
#  print "FALSE \n";
#}
#


sub display_base_info() {
 
  #
  # Name
  #
  print "* Name: $facts->{'ansible_hostname'}, Domain: $facts->{'ansible_domain'} \n";


  #
  # Platform 
  #
  my $vendor = $facts->{'ansible_system_vendor'};
  $vendor =~ s/ Inc.//;
  $vendor =~ s/ Computer Corporation//;
  $vendor =~ s/,//;
  $vendor =~ s/System Manufacturer/Generic/;
  $vendor =~ s/ Corporation//;

  my $product =  $facts->{'ansible_product_name'};
  $product =~ s/VMware Virtual Platform/Virtual Machine/;
  $product =~ s/System Product Name/Server/;
  $product =~ s/ *$//;
  $product =~ s/^ *IBM *//;
  $product =~ s/System //;
  $product =~ s/-\[/(/;
  $product =~ s/\]-/)/;

  print "* Platform: $vendor $product, BIOS: $facts->{'ansible_bios_version'}, Serial: $facts->{'ansible_product_serial'} \n";


  #
  # CPU 
  #
  my $cpu =  $facts->{'ansible_processor'}->[0];
  $cpu =~ s/\(R\)//g;
  $cpu =~ s/\(TM\)//g;
  $cpu =~ s/\(tm\)//g;
  #$cpu =~ s/ 0 \@/ @/;
  $cpu =~ s/GHz/ GHz/;
  $cpu =~ s/CPU *//;
  $cpu =~ s/ *\@/ @/;

  my $cores = $facts->{'ansible_processor_cores'} * $facts->{'ansible_processor_count'};

  print "* CPU(s): $facts->{'ansible_processor_count'}x $cpu; Total physical cores: $cores, Total threads: $facts->{'ansible_processor_vcpus'} \n";


  #
  # Memory
  #
  print "* Memory: $facts->{'ansible_memtotal_mb'} MB RAM, $facts->{'ansible_swaptotal_mb'} MB swap \n";


  #
  # OS
  #
  #print "OS class:  $facts->{'ansible_system'} / $facts->{'ansible_os_family'} $facts->{'ansible_distribution_major_version'}  \n";
  print "* OS:  $facts->{'ansible_distribution'} $facts->{'ansible_distribution_version'} $facts->{'ansible_distribution_release'} ($facts->{'ansible_architecture'}), Repos ($facts->{'ansible_pkg_mgr'}): --- \n";

  print "\n";

}

sub display_network_info() {

  print "=== Network interfaces ===\n";

  print "{| class=\"wikitable\" \n";
  for my $iface ( sort @{$facts->{'ansible_interfaces'}} ) {
    if ($iface ne 'lo') {
         
      my $priv_ip = $facts->{'ansible_' . $iface}->{'ipv4'}->{'address'} ;

      # get ifacename from /etc/hosts based on priv IP
      my $if_hostname = $facts->{'ansible_' . $iface}->{'ipv4'}->{'hostname'} ;

      # resolve public IP from ifacename
      my $pub_ip;
      my @hostinfo = gethostbyname($if_hostname);
      if (scalar(@hostinfo) == 0) {
        $pub_ip = "--";
      } else {
        $pub_ip = inet_ntoa($hostinfo[4]);
      }
      if ($priv_ip eq $pub_ip) {
        $priv_ip = "--";
      }


      my $mac = $facts->{'ansible_' . $iface}->{'macaddress'} ;

      print "|-\n";
      print "| <tt>$if_hostname</tt>  || <tt>$pub_ip</tt>  || <tt>$priv_ip</tt>  || <tt>$iface</tt>  || <tt>$mac</tt> \n";
    }
  }

#          'ansible_eth0' => {
#                              'ipv4_secondaries' => [
#                                                      {
#                                                        'netmask' => '255.255.255.0',
#                                                        'network' => '128.91.127.0',
#                                                        'address' => '128.91.127.136'
#                                                      }
#                                                    ],
#                              'ipv4' => {
#                                          'network' => '128.91.127.0',
#                                          'netmask' => '255.255.255.0',
#                                          'address' => '128.91.127.132'
#                                        },
#                              'macaddress' => '14:fe:b5:d2:24:3b',
#                              'device' => 'eth0',
#

#   I would like to add:  
#        {'ansible_eth0'}->{'ipv4'}->{'dnsname'}
#    which would look up the host name based on IP address 
#     may also have a list of aliases for the IP
#    the point is to get a dnsname that can be looked up externally to resolve the public side of a NAT
#


  print "|}\n";

  print "\n";
}

sub display_mount_info() {


  print "=== Mounts ===\n";

  print "{| class=\"wikitable\" \n";

  for my $mount ( @{$facts->{'ansible_mounts'}} ) {

      my $size_mb = sprintf("%d", $mount->{'size_total'} / ( 1024 * 1024 ) ) ;

      if ($size_mb > 1000000 ) {
          $size = sprintf("%d TB", $size_mb / (1024 * 1024) );
      } elsif ($size_mb > 1000 ) {
          $size = sprintf("%d GB", $size_mb / 1024 );
      } else {
          $size = sprintf("%d MB", $size_mb );
      }

      print "|-\n";
      print "| <tt>$mount->{'mount'}</tt>  || <tt>$mount->{'device'}</tt>  || <tt>$size</tt>  || <tt>$mount->{'fstype'}</tt> \n";

  }

  print "|}\n";

  print "\n";
}


print "\n";
print "== Key info ==\n";

display_base_info();
display_network_info();
# cnames...
display_mount_info();

print "\n";

