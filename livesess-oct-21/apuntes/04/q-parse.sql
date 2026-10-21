-- q-parse.sql: cursores de las consultas a la tabla estudiante en el library cache.
-- Se consulta v$sql en lugar de las estadísticas de la sesión (parse count): v$sql
-- muestra los datos por sentencia y no incluye SQL recursivo ni consultas auxiliares.
--   cursores       : sentencias distintas que aún están en el library cache
--   hard_parses    : cargas del cursor en el library cache (columna loads)
--   llamadas_parse : llamadas de parseo (columna parse_calls)
--   soft_parses    : llamadas de parseo que reutilizaron un cursor existente
--   ejecuciones    : ejecuciones de las sentencias
-- group by tipo_version: a partir de 23ai, group by acepta el alias de una columna
-- del select; en versiones anteriores se debía repetir la expresión case completa
column tipo_version format a22
select case
    when sql_text like '%:ph_email%' then 'variables de enlace'
    else 'valores concatenados'
  end as tipo_version,
  count(*) as cursores,
  sum(loads) as hard_parses,
  sum(parse_calls) as llamadas_parse,
  greatest(sum(parse_calls) - sum(loads), 0) as soft_parses,
  sum(executions) as ejecuciones
from v$sql
where parsing_schema_name = 'JORGE0401'
and sql_text like 'select nombre, password from estudiante where email%'
group by tipo_version
order by tipo_version desc;

