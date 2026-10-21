--
-- ej-06-modos-memoria.sql
-- Ejercicio en clase 6 - Modos de administración de la memoria.
-- Identifica el modo de administración de la memoria de la CDB del curso y consulta
-- el asesor de memory_target. Solo realiza consultas: no modifica la configuración.
--
-- Uso:  sqlplus /nolog
--       start ej-06-modos-memoria.sql
--

set verify off
set feedback on
set linesize 180
set pagesize 100

-- password de sys: permite ejecutar el script con el usuario admin del s.o., sin
-- cambiarse al usuario oracle. Aceptable solo en el ambiente del curso.
define sys_pwd = system2

connect sys/&sys_pwd as sysdba

prompt ===> 1. Parámetros que determinan el modo de administración
column name          format a22
column display_value format a12
column isdefault     format a9
select name, display_value, isdefault
from v$parameter
where name in ('memory_size', 'memory_target', 'memory_max_target',
  'sga_target', 'sga_max_size', 'pga_aggregate_target', 'workarea_size_policy')
order by name;

prompt ===> 1a. Tamaño de la SGA
show sga
pause Identificar el modo de administración, [Enter] para continuar

prompt ===> 2. Componentes que AMM redistribuye
column component format a30
select component, trunc(current_size / 1024 / 1024, 2) as current_mb,
  trunc(min_size / 1024 / 1024, 2) as min_mb,
  trunc(max_size / 1024 / 1024, 2) as max_mb,
  oper_count
from v$memory_dynamic_components
where current_size > 0
order by current_size desc;
pause Analizar resultados, [Enter] para continuar

prompt ===> 3. Asesor de memory_target
select memory_size, memory_size_factor, estd_db_time, estd_db_time_factor
from v$memory_target_advice
order by memory_size;
pause Analizar estd_db_time_factor, [Enter] para terminar

