-- q-hard-parse.sql: hard parses realizados por la sesión actual.
-- valor      = total acumulado desde el inicio de la sesión.
-- diferencia = hard parses desde la ejecución anterior de este script.
-- A diferencia de v$sql, esta estadística también cuenta los cursores que ya
-- salieron del library cache.
-- Requiere la variable :prev_hard (definida en el script principal). Ambas sentencias
-- usan variables de enlace: solo su primera ejecución hace hard parse.
set feedback off
select n.name, m.value, m.value - :prev_hard as diferencia
from v$mystat m
join v$statname n on m.statistic# = n.statistic#
where n.name = 'parse count (hard)';

-- guarda el valor actual para calcular la diferencia en la siguiente ejecución
begin
  select m.value into :prev_hard
  from v$mystat m
  join v$statname n on m.statistic# = n.statistic#
  where n.name = 'parse count (hard)';
end;
/
set feedback on

