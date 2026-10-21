--
-- ej-05-demo-pga.sql
-- Ejercicio en clase 5 - SQL work areas.
-- Ordena 1,000,000 de registros con administración automática de la PGA y después
-- con work areas de tamaño manual (sort_area_size = 64 KB), y compara la memoria
-- empleada y el uso del tablespace temporal.
--
-- Requiere el script auxiliar q-pga.sql en la misma carpeta.
-- Uso:  sqlplus /nolog
--       start ej-05-demo-pga.sql
--

whenever sqlerror exit rollback
set verify off
set feedback on
set linesize 180
set pagesize 100

define pdb_name = jrcbda_s2
-- password de sys: permite ejecutar el script con el usuario admin del s.o., sin
-- cambiarse al usuario oracle. Aceptable solo en el ambiente del curso.
define sys_pwd = system2

prompt ===> 1. Parámetros de la PGA
connect sys/&sys_pwd as sysdba
show parameter pga_aggregate_target
show parameter pga_aggregate_limit
show parameter workarea_size_policy
show parameter memory_max_target
-- processes: número máximo de procesos; 3 MB x processes es una de las reglas del
-- valor por default de pga_aggregate_limit
show parameter processes

prompt ===> 1a. Objetivo actual de la PGA calculado por AMM
column component format a25
select component, trunc(current_size / 1024 / 1024, 2) as current_mb
from v$memory_dynamic_components
where component = 'PGA Target';
pause Analizar resultados, [Enter] para continuar

prompt ===> 2. Creando al usuario jorge0401 en &pdb_name
alter session set container = &pdb_name;
drop user if exists jorge0401 cascade;
create user jorge0401 identified by jorge quota unlimited on users;
grant create session, create table to jorge0401;
-- privilegios para consultar las estadísticas de la sesión y el plan de ejecución
-- con dbms_xplan.display_cursor
grant select on sys.v_$mystat to jorge0401;
grant select on sys.v_$statname to jorge0401;
grant select on sys.v_$session to jorge0401;
grant select on sys.v_$sql to jorge0401;
grant select on sys.v_$sql_plan to jorge0401;
grant select on sys.v_$sql_plan_statistics_all to jorge0401;

whenever sqlerror continue

connect jorge0401/jorge@&pdb_name

prompt ===> 2a. Creando la tabla t_orden con 1,000,000 de registros
create table t_orden (
  id    number(10,0) constraint t_orden_pk primary key,
  valor varchar2(100)
);

-- 1,000 x 1,000 = 1,000,000 de registros con una cadena aleatoria de 20 caracteres
insert /*+ append */ into t_orden (id, valor)
select rownum, dbms_random.string('x', 20)
from (select level from dual connect by level <= 1000) a,
  (select level from dual connect by level <= 1000) b;
commit;

-- sin serveroutput: display_cursor muestra el plan de la última sentencia de la sesión
set serveroutput off
column name  format a25
column valor format 999,999,990.99
-- el plan con allstats last y Used-Tmp ocupa alrededor de 145 caracteres por renglón
column plan_table_output format a150

prompt ===> 3. Ordenamiento con administración automática de la PGA
prompt      Estadísticas antes:
@@q-pga.sql

-- row_number() over (order by valor) obliga a ordenar los 1,000,000 de registros;
-- max(rn) evita enviar el millón de renglones a la pantalla.
-- gather_plan_statistics registra las estadísticas reales de ejecución del plan.
set timing on
select /*+ gather_plan_statistics */ max(rn) as max_rn
from (select row_number() over (order by valor) as rn from t_orden);
set timing off

-- display_cursor sin sql_id muestra el plan de la última sentencia de la sesión, por
-- lo que debe ejecutarse justo después de la consulta y antes de q-pga.sql
prompt ===> 3a. Plan con estadísticas de ejecución (allstats last)
select plan_table_output
from table(dbms_xplan.display_cursor(format => 'allstats last'));

prompt ===> 3b. Estadísticas después:
@@q-pga.sql
pause Analizar el plan (OMem, 1Mem, Used-Mem) y las estadísticas, [Enter] para continuar

prompt ===> 4. Ordenamiento con work areas de tamaño manual (64 KB)
alter session set workarea_size_policy = manual;
alter session set sort_area_size = 65536;

prompt      Estadísticas antes:
@@q-pga.sql

set timing on
select /*+ gather_plan_statistics */ max(rn) as max_rn
from (select row_number() over (order by valor) as rn from t_orden);
set timing off

prompt ===> 4a. Plan con estadísticas de ejecución (allstats last)
select plan_table_output
from table(dbms_xplan.display_cursor(format => 'allstats last'));

prompt ===> 4b. Estadísticas después:
@@q-pga.sql
pause Comparar plan y estadísticas con los pasos 3a y 3b, [Enter] para continuar

prompt ===> 5. Limpieza final
connect sys/&sys_pwd as sysdba
alter session set container = &pdb_name;
drop user jorge0401 cascade;

