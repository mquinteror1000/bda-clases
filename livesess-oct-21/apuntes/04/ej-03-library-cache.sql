--@Autor(es):       <Nombre del autor o autores>
--@Fecha creación:  dd/mm/yyyy
--@Descripción: Ejercicio en clase 3 - Library cache.
--              Compara el uso del library cache entre SQL dinámico con valores concatenados y
--              SQL dinámico con variables de enlace, e ilustra la inyección de SQL.
-- Requiere los scripts auxiliares q-parse.sql y q-hard-parse.sql en la misma carpeta.
-- Uso:  sqlplus /nolog
--       start ej-03-demo-library-cache.sql
--

whenever sqlerror exit rollback
set verify off
set feedback on

define pdb_name = jrcbda_s2
define sys_pwd = system2

prompt ===> Creando al usuario jorge0401 en &pdb_name
connect sys/&sys_pwd as sysdba
alter session set container = &pdb_name;

drop user if exists jorge0401 cascade;
create user jorge0401 identified by jorge quota unlimited on users;
grant create session, create table, create procedure to jorge0401;
-- privilegios para consultar los cursores del library cache y las estadísticas de
-- la sesión
grant select on sys.v_$sql to jorge0401;
grant select on sys.v_$mystat to jorge0401;
grant select on sys.v_$statname to jorge0401;

prompt ===> Conectando como jorge0401
connect jorge0401/jorge@&pdb_name

prompt ===> Creando y poblando la tabla estudiante (10,000 registros)
create table estudiante (
  nombre     varchar2(20),
  password   varchar2(20),
  email      varchar2(20),
  num_cuenta varchar2(20)
);

declare
  v_query varchar2(1000);
begin
  v_query :='
    insert into estudiante(nombre,password,email,num_cuenta)
    values(:ph1,:ph2,:ph3,:ph4)';
  dbms_output.put_line('Ejecutando query :'||v_query);
  for i in 1..10000 loop
    execute immediate v_query using 'n'||i,'p'||i,'e'||i,'c'||i;
  end loop;
end;
/
commit;

-- el índice hace que cada búsqueda sea rápida, de modo que la diferencia de tiempos
-- entre ambas versiones se deba principalmente al costo del parseo
create index estudiante_email_ix on estudiante (email);

prompt ===> Creando la versión ineficiente (valores concatenados)
create or replace procedure get_estudiante_ineficiente(
  p_email      varchar2,
  p_num_cuenta varchar2 default null
) is
  v_query varchar2(1000);
  type r_estudiante is record (
    e_nombre   estudiante.nombre%type,
    e_password estudiante.password%type
  );
  type t_estudiante is table of r_estudiante;
  list_estudiante t_estudiante;
begin
  if p_num_cuenta is not null then
    v_query := 'select nombre, password from estudiante where email = '''
      || p_email || ''' and num_cuenta = ''' || p_num_cuenta || '''';
  else
    v_query := 'select nombre, password from estudiante where email = '''
      || p_email || '''';
  end if;
  dbms_output.put_line('Ejecutando query: ' || v_query);
  execute immediate v_query bulk collect into list_estudiante;
  dbms_output.put_line('--- Estudiantes encontrados: ---');
  for i in 1 .. list_estudiante.count loop
    dbms_output.put_line('Nombre: ' || list_estudiante(i).e_nombre
      || ', Password: ' || list_estudiante(i).e_password);
  end loop;
end;
/
show errors

prompt ===> Creando la versión corregida (variables de enlace)
create or replace procedure get_estudiante(
  p_email      varchar2,
  p_num_cuenta varchar2 default null
) is
  v_query varchar2(1000);
  type r_estudiante is record (
    e_nombre   estudiante.nombre%type,
    e_password estudiante.password%type
  );
  type t_estudiante is table of r_estudiante;
  list_estudiante t_estudiante;
begin
  if p_num_cuenta is not null then
    v_query := 'select nombre, password from estudiante'
      || ' where email = :ph_email and num_cuenta = :ph_num_cuenta';
    execute immediate v_query bulk collect into list_estudiante
      using p_email, p_num_cuenta;
  else
    v_query := 'select nombre, password from estudiante where email = :ph_email';
    execute immediate v_query bulk collect into list_estudiante
      using p_email;
  end if;
  dbms_output.put_line('--- Estudiantes encontrados: ---');
  for i in 1 .. list_estudiante.count loop
    dbms_output.put_line('Nombre: ' || list_estudiante(i).e_nombre
      || ', Password: ' || list_estudiante(i).e_password);
  end loop;
end;
/
show errors

set linesize 200
column cursores       format 999,999
column hard_parses    format 999,999
column llamadas_parse format 999,999
column soft_parses    format 999,999
column ejecuciones    format 999,999
column name           format a20
column value          format 999,999
column diferencia     format 999,999

-- valor previo de parse count (hard), para calcular la diferencia en q-hard-parse.sql
variable prev_hard number
exec :prev_hard := 0

-- primera ejecución de q-hard-parse.sql sin mostrar resultados: el hard parse de sus
-- propias sentencias no se suma a ninguna de las mediciones del ejercicio
set termout off
@@q-hard-parse.sql
set termout on

-- sin serveroutput, dbms_output no acumula los mensajes de las 10,000 ejecuciones
set serveroutput off

prompt
prompt ===> 1. Versión ineficiente: 10,000 ejecuciones con valores distintos
prompt Cursores antes (sin renglones: aún no se ejecuta ninguna versión):
@@q-parse.sql
prompt Estadística Hard parses acumulada de la sesión antes:
@@q-hard-parse.sql
Pause  Comenzando ejecuciones, [Enter] Para comenzar...
set timing on
begin
  for i in 1 .. 10000 loop
    get_estudiante_ineficiente('e' || i, 'c' || i);
  end loop;
end;
/
set timing off
prompt Ejecuciones concluidas
prompt Estadística Hard parses acumulada de la sesión durante las 10,000 ejecuciones:
@@q-hard-parse.sql
prompt Cursores después:
@@q-parse.sql

pause Analizar resultados, [Enter] Para continuar con la versión eficiente
prompt ===> 2. Versión con variables de enlace: 10,000 ejecuciones
prompt Cursores antes:
@@q-parse.sql
prompt Estadística Hard parses acumulada de la sesión antes:
@@q-hard-parse.sql
Prompt Comenzando ejecuciones...
set timing on
begin
  for i in 1 .. 10000 loop
    get_estudiante('e' || i, 'c' || i);
  end loop;
end;
/
set timing off
prompt Estadística Hard parses acumulada de la sesión durante las 10,000 ejecuciones:
@@q-hard-parse.sql
prompt Cursores después:
@@q-parse.sql
pause Analizar resultados, [Enter] Para continuar con Inyección SQL


prompt ===> 3. Inyección de SQL (se conservan solo 5 registros por simplicidad)
-- se dejan solo 5 estudiantes para que la salida sea legible
delete from estudiante where to_number(substr(email, 2)) > 5;
commit;
set serveroutput on

prompt  Versión ineficiente: invocación normal
exec get_estudiante_ineficiente('e1', 'c1')

prompt  Versión ineficiente: invocación con inyección
exec get_estudiante_ineficiente('e1', 'c1'' or 1=''1')

prompt  Versión corregida: la misma invocación con inyección
exec get_estudiante('e1', 'c1'' or 1=''1')

prompt Listo!
exit

