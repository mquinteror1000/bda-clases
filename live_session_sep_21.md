```shellsession

Host shared a Live Share terminal. Enter to type.dockerBda2
c2-bda-jrc
[root@h2-bda-jrc /]# cat start-cdb.sh 
#!/bin/bash
# @Descripcion  Utilidad para levantar el listener y la instancia de la CDB del
#               contenedor, verificando el estado antes de intentarlo (idempotente).
#               Ubicación sugerida: / dentro del contenedor. Ejecutar como root; el
#               script hace su - oracle internamente para autenticar por sistema
#               operativo en cada operación.

if [ "$(whoami)" != "root" ]; then
  echo "ERROR: este script debe ejecutarse como el usuario root"
  exit 1
fi

echo "Verificando el listener..."
if su - oracle -c "lsnrctl status" >/dev/null 2>&1; then
  echo "El listener ya esta en ejecucion"
else
  echo "Iniciando el listener..."
  su - oracle -c "lsnrctl start"
fi

echo "Verificando el estado de la instancia..."
estado=$(su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
set heading off feedback off pagesize 0
select status from v\$instance;
exit
EOF
)
estado=$(echo "${estado}" | tr -d '[:space:]')

if [ "${estado}" = "OPEN" ]; then
  echo "La instancia ya esta abierta (OPEN)"
else
  echo "Iniciando la instancia..."
  su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
startup
exit
EOF
fi

echo "Cambiando al usuario admin"
exec su - jorge
echo "Listo."
#!/bin/bash
# @Descripcion  Utilidad para levantar el listener y la instancia de la CDB del
#               contenedor, verificando el estado antes de intentarlo (idempotente).
#               Ubicación sugerida: / dentro del contenedor. Ejecutar como root; el
#               script hace su - oracle internamente para autenticar por sistema
#               operativo en cada operación.

if [ "$(whoami)" != "root" ]; then
  echo "ERROR: este script debe ejecutarse como el usuario root"
  exit 1
fi

echo "Verificando el listener..."
if su - oracle -c "lsnrctl status" >/dev/null 2>&1; then
  echo "El listener ya esta en ejecucion"
else
  echo "Iniciando el listener..."
  su - oracle -c "lsnrctl start"
fi

echo "Verificando el estado de la instancia..."
estado=$(su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
set heading off feedback off pagesize 0
select status from v\$instance;
exit
EOF
)
estado=$(echo "${estado}" | tr -d '[:space:]')

if [ "${estado}" = "OPEN" ]; then
  echo "La instancia ya esta abierta (OPEN)"
else
  echo "Iniciando la instancia..."
  su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
startup
exit
EOF
fi

echo "Cambiando al usuario admin"
exec su - jorge
echo "Listo."
[root@h2-bda-jrc /]# ll
total 88
dr-xr-xr-x    2 root root 4096 Oct 26  2024 afs
lrwxrwxrwx    1 root root    7 Oct 26  2024 bin -> usr/bin
dr-xr-xr-x.   1 root root 4096 Jun 22  2025 boot
drwxr-xr-x    5 root root  360 Sep 21 08:24 dev
drwxr-xr-x.   1 root root 4096 Sep  9  2025 etc
drwxr-xr-x.   1 root root 4096 Jun 22  2025 home
lrwxrwxrwx    1 root root    7 Oct 26  2024 lib -> usr/lib
lrwxrwxrwx    1 root root    9 Oct 26  2024 lib64 -> usr/lib64
drwxr-xr-x    2 root root 4096 Oct 26  2024 media
drwxr-xr-x    2 root root 4096 Oct 26  2024 mnt
drwxr-xr-x.   1 root root 4096 Jun 22  2025 opt
dr-xr-xr-x  428 root root    0 Sep 21 08:24 proc
dr-xr-x---.   1 root root 4096 Sep 14 08:01 root
drwxr-xr-x.   1 root root 4096 Jun 24  2025 run
lrwxrwxrwx    1 root root    8 Oct 26  2024 sbin -> usr/sbin
drwxr-xr-x    2 root root 4096 Oct 26  2024 srv
-rwxr-xr-x    1 root root 2456 Sep 20 23:33 start-cdb.sh
dr-xr-xr-x   13 root root    0 Sep 21 08:24 sys
drwxrwxrwt.   1 root root 4096 Jun  1 09:28 tmp
drwxr-xr-x   11 root root 4096 Aug  6  2025 unam
drwxr-xr-x.   1 root root 4096 Apr 28  2025 usr
drwxr-xr-x.   1 root root 4096 Apr 28  2025 var
[root@h2-bda-jrc /]# ./start-cdb.sh 
Verificando el listener...
Iniciando el listener...

LSNRCTL for Linux: Version 23.0.0.0.0 - Production on 21-SEP-2026 08:29:32

Copyright (c) 1991, 2025, Oracle.  All rights reserved.

Starting /opt/oracle/product/23ai/dbhomeFree/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 23.0.0.0.0 - Production
System parameter file is /opt/oracle/product/23ai/dbhomeFree/network/admin/listener.ora
Log messages written to /opt/oracle/diag/tnslsnr/h2-bda-jrc/listener/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=h2-bda-jrc.fi.unam)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=h2-bda-jrc.fi.unam)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 23.0.0.0.0 - Production
Start Date                21-SEP-2026 08:29:34
Uptime                    0 days 0 hr. 0 min. 0 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /opt/oracle/product/23ai/dbhomeFree/network/admin/listener.ora
Listener Log File         /opt/oracle/diag/tnslsnr/h2-bda-jrc/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=h2-bda-jrc.fi.unam)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
The listener supports no services
The command completed successfully
Verificando el estado de la instancia...
Iniciando la instancia...
ORACLE instance started.

Total System Global Area 1070283152 bytes
Fixed Size                  4929936 bytes
Variable Size             759169024 bytes
Database Buffers           92274688 bytes
Redo Buffers                4194304 bytes
In-Memory Area            209715200 bytes
Database mounted.
Database opened.
Cambiando al usuario admin
Last login: Sun Sep 20 23:33:45 CST 2026 on pts/0
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ sqlplus sys/system1 as sysdba

SQL*Plus: Release 23.0.0.0.0 - Production on Mon Sep 21 08:32:44 2026
Version 23.8.0.25.04

Copyright (c) 1982, 2025, Oracle.  All rights reserved.

ERROR:
ORA-01017: invalid credential or not authorized; logon denied
Help: https://docs.oracle.com/error-help/db/ora-01017/


Enter user-name: 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ 
[jorge@h2-bda-jrc ~]$ sqlplus sys/system2 as sysdba

SQL*Plus: Release 23.0.0.0.0 - Production on Mon Sep 21 08:32:53 2026
Version 23.8.0.25.04

Copyright (c) 1982, 2025, Oracle.  All rights reserved.

Last Successful login time: Mon Sep 14 2026 08:40:09 -06:00

Connected to:
Oracle Database 23ai Free Release 23.0.0.0.0 - Develop, Learn, and Run for Free
Version 23.8.0.25.04

sys@free> 
sys@free> 
sys@free> 
sys@free> shutdown abort
ORACLE instance shut down.
sys@free> 
sys@free> 
sys@free> startup nomount
ORACLE instance started.

Total System Global Area 1070283152 bytes
Fixed Size                  4929936 bytes
Variable Size             759169024 bytes
Database Buffers           92274688 bytes
Redo Buffers                4194304 bytes
In-Memory Area            209715200 bytes
select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4  from v$instance;

INSTANCE_NAME
------------------------------------------------
STARTUP_TIME
---------------------------------------------------------
STATUS
------------------------------------
DATABASE_STATUS
---------------------------------------------------
free
2026/09/21 08:33:13
STARTED
ACTIVE


sys@free> set linesize window
sys@free> col instance_name format a30
sys@free> col startup_time format a30
sys@free> col status format a10
sys@free> col database_status format a15
sys@free> 
sys@free> run
  1  select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4* from v$instance

INSTANCE_NAME                  STARTUP_TIME                   STATUS
------------------------------ ------------------------------ ----------
DATABASE_STATUS
---------------
free                           2026/09/21 08:33:13            STARTED
ACTIVE


sys@free> col instance_name format a20
sys@free> 
sys@free> 
sys@free> run
  1  select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4* from v$instance

INSTANCE_NAME        STARTUP_TIME                   STATUS     DATABASE_STATUS
-------------------- ------------------------------ ---------- ---------------
free                 2026/09/21 08:33:13            STARTED    ACTIVE

sys@free> alter database mount;

Database altered.

select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4  from v$instance;

INSTANCE_NAME        STARTUP_TIME                   STATUS     DATABASE_STATUS
-------------------- ------------------------------ ---------- ---------------
free                 2026/09/21 08:33:13            MOUNTED    ACTIVE

sys@free> alter database open;

Database altered.

select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4  from v$instance;

INSTANCE_NAME        STARTUP_TIME                   STATUS     DATABASE_STATUS
-------------------- ------------------------------ ---------- ---------------
free                 2026/09/21 08:33:13            OPEN       ACTIVE

sys@free> show parameter undo_tablespace;

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_tablespace                      string      UNDOTBS1
select value from v$system_parameter 
  2  where name = 'undo_tablespace';

VALUE
-------------------------------------------------------------------------------------
UNDOTBS1

UNDOTBS1

sys@free> alter database close;

Database altered.

select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  2    3    status, database_status
  4  from v$instance;

INSTANCE_NAME        STARTUP_TIME                   STATUS     DATABASE_STATUS
-------------------- ------------------------------ ---------- ---------------
free                 2026/09/21 08:33:13            MOUNTED    ACTIVE

sys@free> shutdown immediate;
ORA-01109: database not open
Help: https://docs.oracle.com/error-help/db/ora-01109/


Database dismounted.
ORACLE instance shut down.
sys@free> startup mount
ORACLE instance started.

Total System Global Area 1070283152 bytes
Fixed Size                  4929936 bytes
Variable Size             759169024 bytes
Database Buffers           92274688 bytes
Redo Buffers                4194304 bytes
In-Memory Area            209715200 bytes
Database mounted.
sys@free> alter database open read only;

Database altered.

sys@free> 
select instance_name,
  2    to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  3    status, database_status
  4  from v$instance;

INSTANCE_NAME        STARTUP_TIME                   STATUS     DATABASE_STATUS
-------------------- ------------------------------ ---------- ---------------
free                 2026/09/21 08:45:17            OPEN       ACTIVE

sys@free> create table test(id number);
create table test(id number)
*
ERROR at line 1:
ORA-16000: Attempting to modify database or pluggable database that is open for
read-only access.
Help: https://docs.oracle.com/error-help/db/ora-16000/


sys@free> shutdown abort
ORACLE instance shut down.
sys@free> 

```
