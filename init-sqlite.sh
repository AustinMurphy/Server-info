#!/bin/bash
#
#  Initialize an SQLite DB for the server info collection
#


# SQLite DB file
DB="./server-info.db"


SQLCMD="BEGIN TRANSACTION;

create table domain (server, date, name, domain); 

create table platform (server, date, manf, product, fwver, serial, warrexp); 
create table cpus (server, date, manf, fam, freq, num, numfree); 
create table mem (server, date, totmb, nummods, modsize, max); 
create table os (server, date, brand, product, ver, arch, yumrepos); 
 
create table ifaces (server, date, dnsname, pubip, privip, iface, mac); 
create table cnames (server, date, cname, dnsname); 
create table mountpts (server, date, mountpt, device, size, fstype); 

COMMIT; "


if [ -a $DB ] 
then
  echo "Database already exists!  --  $DB "
else
  #echo "$SQLCMD" 
  echo "Creating Server Info Database file:  $DB "
  echo "$SQLCMD" | sqlite $DB
fi


