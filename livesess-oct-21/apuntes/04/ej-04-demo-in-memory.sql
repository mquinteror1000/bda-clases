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

