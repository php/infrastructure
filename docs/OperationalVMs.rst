=================
VM Specifications
=================

=============================== ======== ============================= =====================================================================================
Host                            Location VM Specs                      Purpose
=============================== ======== ============================= =====================================================================================
jump-ams-1                      AMS3     512 MB RAM / 10 GB Disk       SSH Jump Host
jump-sfo-1                      SFO3     512 MB RAM / 10 GB Disk       SSH Jump Host
rsync0-ams.internal.php.net     AMS3     4 GB RAM / 60 GB Disk         Rsync Host
service0-ams.internal.php.net   AMS3     4 GB RAM / 80 GB Disk         Museum
service1-ams.internal.php.net   AMS3     2 GB RAM / 60 GB Disk         Wiki
service2-ams.internal.php.net   AMS3     16 GB RAM / 320 GB Disk       Static Sites (without DB): doc, downloads, people, shared, qa, talks, windows, www
service3-ams.internal.php.net   AMS3     8 GB RAM / 160 GB Disk        Dynamic Sites (with DB): bugs, main, pecl 
service4-ams.internal.php.net   AMS3     4 GB RAM / 60 GB Disk         Matomo Analytics
=============================== ======== ============================= =====================================================================================
