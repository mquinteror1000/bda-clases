-- q-redo.sql: redo y undo generados por la sesión actual.
-- valor      = total acumulado desde el inicio de la sesión.
-- diferencia = generado desde la ejecución anterior de este script.
-- Requiere las variables :prev_redo y :prev_undo (definidas en el script principal).
-- Ambas sentencias usan variables de enlace: su texto no cambia entre ejecuciones,
-- por lo que solo la primera ejecución hace hard parse.
set feedback off
select n.name, m.value,
  m.value - decode(n.name, 'redo size', :prev_redo, :prev_undo) as diferencia
from v$mystat m
join v$statname n on m.statistic# = n.statistic#
where n.name in ('redo size', 'undo change vector size')
order by n.name;

-- guarda los valores actuales para calcular la diferencia en la siguiente ejecución
begin
  select max(decode(n.name, 'redo size', m.value)),
    max(decode(n.name, 'undo change vector size', m.value))
  into :prev_redo, :prev_undo
  from v$mystat m
  join v$statname n on m.statistic# = n.statistic#
  where n.name in ('redo size', 'undo change vector size');
end;
/
set feedback on
