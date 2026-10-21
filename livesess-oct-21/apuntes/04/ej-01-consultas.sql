--@Autor(es):       <Nombre del autor o autores>
--@Fecha creación:  dd/mm/yyyy
--@Descripción:  Ejercicio en clase 1 -  Consultas del uso de Memoria

Prompt ==> Conectando a cdb$root como sysdba
connect sys/system2 as sysdba

set linesize 200
set pagesize 100
col name format a40
col display_value format a30
col component format a30
col parameter format a30


prompt A. Distribución de la SGA
select name, trunc(value / 1024 / 1024, 2) as value_mb
from v$sga;
pause Analizar resultados, [Enter] para continuar

prompt B. Total de la SGA
select trunc(sum(value) / 1024 / 1024, 2) as total_sga_mb
from v$sga;
pause Analizar resultados, [Enter] para continuar

prompt C. Comparación con memory_target y memory_max_target
select name, display_value
from v$parameter
where name in ('memory_target', 'memory_max_target');
pause Analizar resultados, [Enter] para continuar

prompt D. Componentes dinámicos
select component, trunc(current_size / 1024 / 1024, 2) as current_size_mb
from v$sga_dynamic_components
order by current_size desc;
pause Analizar resultados, [Enter] para continuar

prompt E. Operaciones de Ajuste
select component, oper_type, parameter,
  trunc(initial_size / 1024 / 1024, 2) as initial_mb,
  trunc(final_size / 1024 / 1024, 2) as final_mb,
  trunc((final_size - initial_size) / 1024 / 1024, 2) as incremento_mb,
  status,
  to_char(end_time, 'yyyy-mm-dd hh24:mi:ss') as end_time
from v$sga_resize_ops
order by end_time;
pause Analizar resultados, [Enter] para continuar

Prompt F. Memoria libre de la SGA
select trunc(current_size / 1024 / 1024, 2) as free_mb
from v$sga_dynamic_free_memory;
pause Analizar resultados, [Enter] para continuar

Prompt G.  Vista v$sgainfo
select name, trunc(bytes / 1024 / 1024, 2) as mb, resizeable
from v$sgainfo;



