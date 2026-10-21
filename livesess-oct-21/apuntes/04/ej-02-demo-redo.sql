--
-- demo-redo.sql
-- Ejercicio en clase 2 - Generación de redo y undo por sentencias DML.
-- Tema 04 - Redo log buffer y ciclo de vida de un cambio.
--
-- Requiere el script auxiliar q-redo.sql en la misma carpeta.
-- Uso:  sqlplus /nolog
--       start demo-redo.sql
--

whenever sqlerror exit rollback
set verify off
set feedback on

define pdb_name = jrcbda_s2
-- password de sys: permite ejecutar el script con el usuario admin del s.o., sin
-- cambiarse al usuario oracle. Aceptable solo en el ambiente del curso.
define sys_pwd = system2

prompt ===> 0. Creando al usuario jorge0401 en &pdb_name
connect sys/&sys_pwd as sysdba
alter session set container = &pdb_name;

drop user if exists jorge0401 cascade;
create user jorge0401 identified by jorge quota unlimited on users;
grant create session, create table to jorge0401;
-- privilegios para consultar las estadísticas de la propia sesión
grant select on sys.v_$mystat to jorge0401;
grant select on sys.v_$statname to jorge0401;

whenever sqlerror continue

prompt ===> Conectando como jorge0401
connect jorge0401/jorge@&pdb_name

-- segment creation immediate: el segmento de la tabla se crea junto con la tabla.
-- Con el valor por omisión (deferred), el segmento se crea en el primer insert, y el
-- redo de esa creación se sumaría al redo del insert de un registro (paso 2).
create table test_redo (
  id     number(10,0) constraint test_redo_pk primary key,
  nombre varchar2(100)
) segment creation immediate;

column name       format a30
column value      format 999,999,999
column diferencia format 999,999,999
column nombre     format a30

-- valores de la ejecución anterior de q-redo.sql, para calcular la diferencia
variable prev_redo number
variable prev_undo number
exec :prev_redo := 0; :prev_undo := 0;

-- primera ejecución de q-redo.sql sin mostrar resultados: el hard parse de sus
-- sentencias genera algo de redo, que así no se suma a ningún paso del ejercicio
set termout off
@@q-redo.sql
set termout on

prompt
prompt ===> 1. Valores iniciales de la sesión
prompt      (diferencia en 0: consultar las estadísticas no genera redo)
@@q-redo.sql

prompt ===> 2. Insert de un registro
insert into test_redo (id, nombre) values (1, 'registro de prueba');
@@q-redo.sql
pause Analizar resultados, [Enter] para continuar

prompt ===> 3. Select: primera ejecución
select * from test_redo;
@@q-redo.sql

prompt ===> 3a. Select: segunda ejecución de la misma sentencia
select * from test_redo;
@@q-redo.sql
pause Comparar ambas ejecuciones del select, [Enter] para continuar

prompt ===> 4. Update sin commit: genera redo aun sin confirmar
update test_redo set nombre = upper(nombre) where id = 1;
@@q-redo.sql
pause Analizar resultados, [Enter] para continuar

prompt ===> 5. Commit: agrega muy poco redo (registro de confirmación)
commit;
@@q-redo.sql
pause Analizar resultados, [Enter] para continuar

prompt ===> 6. Insert de 10,000 registros
insert into test_redo (id, nombre)
select level + 1, rpad('x', 100, 'x')
from dual
connect by level <= 10000;
commit;
@@q-redo.sql
pause Analizar resultados, [Enter] para continuar

prompt ===> 7. Delete de los 10,000 registros
delete from test_redo where id > 1;
commit;
@@q-redo.sql
pause Analizar resultados, [Enter] para continuar

prompt ===> 8. Limpieza final
connect sys/&sys_pwd as sysdba
alter session set container = &pdb_name;
drop user jorge0401 cascade;

