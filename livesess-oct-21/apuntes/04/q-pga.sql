-- q-pga.sql: ordenamientos y memoria PGA de la sesión actual.
-- Valores acumulados desde el inicio de la sesión; la memoria se muestra en MB.
select n.name,
  case
    when n.name like 'session pga memory%' then round(m.value / 1024 / 1024, 2)
    else m.value
  end as valor
from v$mystat m
join v$statname n on m.statistic# = n.statistic#
where n.name in ('sorts (memory)', 'sorts (disk)', 'session pga memory',
  'session pga memory max')
order by n.name;

