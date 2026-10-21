## Octubre 21

Ejemplo de in memory column store

```sql
--
-- demo-inmemory.sql
-- Ejercicio en clase 4 - In-Memory Area.
-- Habilita la In-Memory Area, carga una tabla de 1,000,000 de registros en el
-- In-Memory column store, compara planes de ejecución y restaura la configuración.
--
-- Uso:  sqlplus /nolog
--       start demo-inmemory.sql
-- Nota: el script reinicia la instancia dos veces.
--

set verify off
set feedback on
set linesize 180
set pagesize 100

define pdb_name = mqrbda_s1
-- password de sys: permite ejecutar el script con el usuario admin del s.o., sin
-- cambiarse al usuario oracle. Aceptable solo en el ambiente del curso.
define sys_pwd = system1

prompt ===> 1. Parámetros de memoria actuales
connect sys/&sys_pwd as sysdba
show parameter memory_target
show parameter memory_max_target
show parameter inmemory_size

prompt ===> 1b. Distribución actual de la SGA
column name format a30
select name, trunc(value / 1024 / 1024, 2) as value_mb
from v$sga;
pause Analizar resultados, [Enter] para continuar

prompt ===> 2. Asignando 200 MB a la In-Memory Area y reiniciando
alter system set inmemory_size = 200M scope = spfile;
shutdown immediate
startup
select name, trunc(value / 1024 / 1024, 2) as value_mb from v$sga;
pause Analizar resultados, [Enter] para continuar

prompt ===> 2a. Memoria de los componentes dinámicos antes de incrementar memory_target
column component format a25
select component, trunc(current_size / 1024 / 1024, 2) as current_mb
from v$memory_dynamic_components
where component in ('shared pool', 'DEFAULT buffer cache', 'In-Memory Area',
  'PGA Target');

prompt ===> 2b. Incrementando memory_target para compensar la In-Memory Area
-- los 200 MB de la In-Memory Area se restan de la memoria que administra la instancia
-- (memory_target = 768M); se incrementa de forma temporal, sin reiniciar, ya que
-- memory_max_target = 2048M. El cambio se pierde en el siguiente reinicio.
alter system set memory_target = 1200M scope = memory;

prompt ===> 2c. Memoria de los componentes dinámicos después del incremento
select component, trunc(current_size / 1024 / 1024, 2) as current_mb
from v$memory_dynamic_components
where component in ('shared pool', 'DEFAULT buffer cache', 'In-Memory Area',
  'PGA Target');
pause Analizar resultados, [Enter] para continuar

prompt ===> 3. Creando al usuario jorge0401 y la tabla venta en &pdb_name
alter session set container = &pdb_name;
drop user if exists jorge0401 cascade;
create user jorge0401 identified by jorge quota unlimited on users;
grant create session, create table to jorge0401;
grant select on sys.v_$im_segments to jorge0401;

connect jorge0401/jorge@&pdb_name

create table venta (
  id       number(10,0) constraint venta_pk primary key,
  fecha    date,
  region   varchar2(10),
  producto varchar2(10),
  monto    number(10,2)
);
-- la cláusula inmemory se agrega después de la carga de datos (paso 4). Si se
-- especifica aquí, la carga al column store inicia con la tabla vacía y termina con
-- estado COMPLETED; los registros insertados después con insert /*+ append */ quedan
-- fuera del column store (bytes_not_populated).

prompt ===> 3b. Cargando la tabla venta con 1,000,000 de registros
-- 1,000 x 1,000 = 1,000,000 de registros; las fechas cubren el último año
insert /*+ append */ into venta (id, fecha, region, producto, monto)
select rownum,
  trunc(sysdate) - mod(rownum, 365),
  'R' || mod(rownum, 8),
  'P' || mod(rownum, 100),
  round(dbms_random.value(10, 5000), 2)
from (select level from dual connect by level <= 1000) a,
  (select level from dual connect by level <= 1000) b;
commit;

-- no se requiere dbms_stats: un insert /*+ append */ sobre una tabla vacía recolecta
-- las estadísticas de la tabla de forma automática (online statistics gathering)
prompt ===> 3c. Estadísticas recolectadas de forma automática por la carga:
select num_rows, to_char(last_analyzed, 'yyyy-mm-dd hh24:mi:ss') as last_analyzed
from user_tables
where table_name = 'VENTA';

prompt ===> 4. Habilitando la tabla venta para el In-Memory column store
-- inmemory priority high: habilita la tabla para el column store; con prioridad, la
--   carga inicia en background sin esperar a que una consulta recorra la tabla.
-- inmemory (columnas): define qué columnas se cargan; con no inmemory (columnas) se
--   excluyen columnas que no se consultan. Sin la cláusula a nivel de tabla, las
--   columnas quedan marcadas pero la tabla no se carga.
-- La misma cláusula puede especificarse en create table, pero conviene agregarla
-- después de cargar los datos.
alter table venta inmemory priority high
  inmemory (id, fecha, region, producto, monto);

-- inmemory = ENABLED confirma que la tabla se cargará en el column store
column inmemory format a10
column inmemory_priority format a10
col table_name format a15
select table_name, inmemory, inmemory_priority
from user_tables
where table_name = 'VENTA';

prompt ===> 5. Esperando a que termine la carga (máximo 120 segundos)
declare
  v_status varchar2(20);
  v_bytes  number;
begin
  for i in 1 .. 60 loop
    begin
      select populate_status, bytes_not_populated into v_status, v_bytes
      from v$im_segments
      where segment_name = 'VENTA';
    exception
      when no_data_found then
        v_status := null;
        v_bytes := null;
    end;
    -- la carga termina cuando el estado es COMPLETED y no quedan bytes por cargar
    exit when v_status = 'COMPLETED' and v_bytes = 0;
    dbms_session.sleep(2);
  end loop;
end;
/

prompt ===> 5b. Comprobando el estado de la carga
column segment_name format a15
select segment_name, populate_status,
  trunc(bytes / 1024 / 1024, 2) as disco_mb,
  trunc(inmemory_size / 1024 / 1024, 2) as inmemory_mb,
  bytes_not_populated
from v$im_segments;
pause Analizar resultados, [Enter] para continuar

prompt ===> 6. Plan de ejecución: total de ventas por región del último mes
-- statement_id permite conservar ambos planes en plan_table para compararlos (paso 7b)
delete from plan_table where statement_id in ('con_im', 'sin_im');
explain plan set statement_id = 'con_im' for
select region, sum(monto) as total
from venta
where fecha >= add_months(trunc(sysdate, 'MM'), -1)
and fecha < trunc(sysdate, 'MM')
group by region;
select plan_table_output
from table(dbms_xplan.display(statement_id => 'con_im', format => 'typical'));

set timing on
select region, sum(monto) as total
from venta
where fecha >= add_months(trunc(sysdate, 'MM'), -1)
and fecha < trunc(sysdate, 'MM')
group by region
order by region;
set timing off
pause Analizar resultados (plan y datos) [Enter] para continuar

prompt ===> 7. Plan de ejecución sin el column store (hint no_inmemory)
explain plan set statement_id = 'sin_im' for
select /*+ no_inmemory */ region, sum(monto) as total
from venta
where fecha >= add_months(trunc(sysdate, 'MM'), -1)
and fecha < trunc(sysdate, 'MM')
group by region;
select plan_table_output
from table(dbms_xplan.display(statement_id => 'sin_im', format => 'typical'));

set timing on
select /*+ no_inmemory */ region, sum(monto) as total
from venta
where fecha >= add_months(trunc(sysdate, 'MM'), -1)
and fecha < trunc(sysdate, 'MM')
group by region
order by region;
set timing off
pause Analizar resultados (plan y datos) [Enter] para continuar

prompt ===> 7b. Desglose del costo de ambos planes: I/O y CPU
-- cost = costo total; io_cost = costo de I/O; cost - io_cost = costo de CPU.
-- La columna cpu_cost está en unidades internas (ciclos de CPU estimados), no en las
-- mismas unidades que cost.
column operacion format a35
select statement_id, id, operation || ' ' || options as operacion,
  cost, io_cost, cost - io_cost as cpu_cost_aprox
from plan_table
where statement_id in ('con_im', 'sin_im')
and cost is not null
order by statement_id, id;
pause Comparar el costo de I/O y de CPU de ambos planes, [Enter] para continuar

prompt ===> 8. Creando un índice sobre fecha y generando los planes nuevamente
-- create index recolecta las estadísticas del índice al crearlo
create index venta_fecha_ix on venta (fecha);

prompt ===> 8a. Consulta del último mes (poco selectiva):
explain plan for
select region, sum(monto) as total
from venta
where fecha >= add_months(trunc(sysdate, 'MM'), -1)
and fecha < trunc(sysdate, 'MM')
group by region;
select plan_table_output from table(dbms_xplan.display(format => 'typical'));

prompt ===> 8b. Consulta de un solo día (muy selectiva):
explain plan for
select region, sum(monto) as total
from venta
where fecha = trunc(sysdate) - 1
group by region;
select plan_table_output from table(dbms_xplan.display(format => 'typical'));
pause Analizar resultados (planes) [Enter] para continuar

prompt ===> 9. Restaurando la configuración original
alter table venta no inmemory;

connect sys/&sys_pwd as sysdba
alter system reset inmemory_size scope = spfile;
shutdown immediate
startup

prompt ===> 9b. Comprobando que la In-Memory Area ya no existe y que memory_target
prompt      regresó a su valor original
show sga
show parameter memory_target
```

Ejecución

```shellsession
[martin@h1-bda-mqr 04]$ sqlplus /nolog @ej-04-demo-in-memory.sql 

SQL*Plus: Release 23.0.0.0.0 - Production on Wed Oct 21 07:33:22 2026
Version 23.8.0.25.04

Copyright (c) 1982, 2025, Oracle.  All rights reserved.

===> 1. Parámetros de memoria actuales
Connected.

NAME                     TYPE     VALUE
------------------------------------ ----------- ------------------------------
memory_target                 big integer 0

NAME                     TYPE     VALUE
------------------------------------ ----------- ------------------------------
memory_max_target             big integer 0

NAME                     TYPE     VALUE
------------------------------------ ----------- ------------------------------
inmemory_size                 big integer 0
===> 1b. Distribución actual de la SGA

NAME                 VALUE_MB
------------------------------ ----------
Fixed Size                 4.69
Variable Size                  448
Database Buffers             1072
Redo Buffers                 4.32

4 rows selected.

Analizar resultados, [Enter] para continuar

===> 2. Asignando 200 MB a la In-Memory Area y reiniciando

System altered.

Database closed.
Database dismounted.
ORACLE instance shut down.
ORACLE instance started.

Total System Global Area 1603287928 bytes
Fixed Size            4922232 bytes
Variable Size          369098752 bytes
Database Buffers     1006632960 bytes
Redo Buffers            4530176 bytes
In-Memory Area          218103808 bytes
Database mounted.
Database opened.

NAME                 VALUE_MB
------------------------------ ----------
Fixed Size                 4.69
Variable Size                  368
Database Buffers              944
Redo Buffers                 4.32
In-Memory Area                  208

5 rows selected.

Analizar resultados, [Enter] para continuar

===> 2a. Memoria de los componentes dinámicos antes de incrementar memory_target

COMPONENT          CURRENT_MB
------------------------- ----------
shared pool             352
DEFAULT buffer cache         864
In-Memory Area             208
PGA Target             512

4 rows selected.

===> 2b. Incrementando memory_target para compensar la In-Memory Area
alter system set memory_target = 1200M scope = memory
*
ERROR at line 1:
ORA-02097: parameter cannot be modified because specified value is invalid
ORA-00837: Specified value of MEMORY_TARGET greater than MEMORY_MAX_TARGET
Help: https://docs.oracle.com/error-help/db/ora-02097/


===> 2c. Memoria de los componentes dinámicos después del incremento

COMPONENT          CURRENT_MB
------------------------- ----------
shared pool             352
DEFAULT buffer cache         864
In-Memory Area             208
PGA Target             512

4 rows selected.

Analizar resultados, [Enter] para continuar

===> 3. Creando al usuario jorge0401 y la tabla venta en mqrbda_s1

Session altered.


User dropped.


User created.


Grant succeeded.


Grant succeeded.

Connected.

Table created.

===> 3b. Cargando la tabla venta con 1,000,000 de registros

1000000 rows created.


Commit complete.

===> 3c. Estadísticas recolectadas de forma automática por la carga:

  NUM_ROWS LAST_ANALYZED
---------- -------------------
   1000000 2026-10-21 07:34:29

1 row selected.

===> 4. Habilitando la tabla venta para el In-Memory column store

Table altered.


TABLE_NAME    INMEMORY   INMEMORY_P
--------------- ---------- ----------
VENTA        ENABLED    HIGH

1 row selected.

===> 5. Esperando a que termine la carga (máximo 120 segundos)

PL/SQL procedure successfully completed.

===> 5b. Comprobando el estado de la carga

SEGMENT_NAME    POPULATE_STAT    DISCO_MB INMEMORY_MB BYTES_NOT_POPULATED
--------------- ------------- ---------- ----------- -------------------
VENTA        COMPLETED       32.32       30.43               0

1 row selected.

Analizar resultados, [Enter] para continuar

===> 6. Plan de ejecución: total de ventas por región del último mes

0 rows deleted.


Explained.


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Plan hash value: 3354199363

--------------------------------------------------------------------------------------
| Id  | Operation             | Name  | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT         |         |       8 |     128 |      74  (42)| 00:00:01 |
|   1 |  HASH GROUP BY             |         |       8 |     128 |      74  (42)| 00:00:01 |
|*  2 |   FILTER             |         |         |         |          |         |
|*  3 |    TABLE ACCESS INMEMORY FULL| VENTA | 85157 |    1330K|      73  (42)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TRUNC(SYSDATE@!,'fmmm')>ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1))
          )
   3 - inmemory("FECHA">=ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1)) AND
          "FECHA"<TRUNC(SYSDATE@!,'fmmm'))
       filter("FECHA">=ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1)) AND
          "FECHA"<TRUNC(SYSDATE@!,'fmmm'))

20 rows selected.


REGION        TOTAL
---------- ----------
R0       25724660.6
R1         25657817
R2       25616681.1
R3       25760637.7
R4         25804822
R5       25853466.1
R6       25883920.3
R7       25821349.9

8 rows selected.

Elapsed: 00:00:00.10
Analizar resultados (plan y datos) [Enter] para continuar

===> 7. Plan de ejecución sin el column store (hint no_inmemory)

Explained.


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Plan hash value: 3354199363

-----------------------------------------------------------------------------
| Id  | Operation        | Name  | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |        |      8 |    128 |  1172   (3)| 00:00:01 |
|   1 |  HASH GROUP BY        |        |      8 |    128 |  1172   (3)| 00:00:01 |
|*  2 |   FILTER        |        |        |        |         |        |
|*  3 |    TABLE ACCESS FULL| VENTA | 85157 |  1330K|  1170   (3)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TRUNC(SYSDATE@!,'fmmm')>ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm')
          ,(-1)))
   3 - filter("FECHA">=ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1)) AND
          "FECHA"<TRUNC(SYSDATE@!,'fmmm'))

18 rows selected.


REGION        TOTAL
---------- ----------
R0       25724660.6
R1         25657817
R2       25616681.1
R3       25760637.7
R4         25804822
R5       25853466.1
R6       25883920.3
R7       25821349.9

8 rows selected.

Elapsed: 00:00:00.12
Analizar resultados (plan y datos) [Enter] para continuar

===> 7b. Desglose del costo de ambos planes: I/O y CPU

STATEMENT_ID                   ID OPERACION                    COST    IO_COST CPU_COST_APROX
------------------------------ ---------- ----------------------------------- ---------- ---------- --------------
con_im                    0 SELECT STATEMENT                  74     43        31
con_im                    1 HASH GROUP BY                   74     43        31
con_im                    3 TABLE ACCESS INMEMORY FULL              73     43        30
sin_im                    0 SELECT STATEMENT                1172       1143        29
sin_im                    1 HASH GROUP BY                 1172       1143        29
sin_im                    3 TABLE ACCESS FULL                1170       1143        27

6 rows selected.

Comparar el costo de I/O y de CPU de ambos planes, [Enter] para continuar

===> 8. Creando un índice sobre fecha y generando los planes nuevamente

Index created.

===> 8a. Consulta del último mes (poco selectiva):

Explained.


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Plan hash value: 3354199363

--------------------------------------------------------------------------------------
| Id  | Operation             | Name  | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT         |         |       8 |     128 |      74  (42)| 00:00:01 |
|   1 |  HASH GROUP BY             |         |       8 |     128 |      74  (42)| 00:00:01 |
|*  2 |   FILTER             |         |         |         |          |         |
|*  3 |    TABLE ACCESS INMEMORY FULL| VENTA | 85157 |    1330K|      73  (42)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TRUNC(SYSDATE@!,'fmmm')>ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1))
          )
   3 - inmemory("FECHA">=ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1)) AND
          "FECHA"<TRUNC(SYSDATE@!,'fmmm'))
       filter("FECHA">=ADD_MONTHS(TRUNC(SYSDATE@!,'fmmm'),(-1)) AND
          "FECHA"<TRUNC(SYSDATE@!,'fmmm'))

20 rows selected.

===> 8b. Consulta de un solo día (muy selectiva):

Explained.


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Plan hash value: 976369476

-------------------------------------------------------------------------------------
| Id  | Operation            | Name  | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT        |        |      8 |    128 |     76  (44)| 00:00:01 |
|   1 |  HASH GROUP BY            |        |      8 |    128 |     76  (44)| 00:00:01 |
|*  2 |   TABLE ACCESS INMEMORY FULL| VENTA |  2740 | 43840 |     75  (43)| 00:00:01 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - inmemory("FECHA"=TRUNC(SYSDATE@!)-1)
       filter("FECHA"=TRUNC(SYSDATE@!)-1)

15 rows selected.

Analizar resultados (planes) [Enter] para continuar

===> 9. Restaurando la configuración original

Table altered.

Connected.

System altered.

Database closed.
Database dismounted.
ORACLE instance shut down.
ORACLE instance started.

Total System Global Area 1603287928 bytes
Fixed Size            4922232 bytes
Variable Size          402653184 bytes
Database Buffers     1191182336 bytes
Redo Buffers            4530176 bytes
Database mounted.
Database opened.
===> 9b. Comprobando que la In-Memory Area ya no existe y que memory_target
regresó a su valor original

Total System Global Area 1603287928 bytes
Fixed Size            4922232 bytes
Variable Size          402653184 bytes
Database Buffers     1191182336 bytes
Redo Buffers            4530176 bytes

NAME                     TYPE     VALUE
------------------------------------ ----------- ------------------------------
memory_target                 big integer 0
sys@free> 
```
