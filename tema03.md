





## 23 sep 2026

ejemplo como crear una politica

```sql
create audit policy nombre_politica​
actions select, update on esquema.tabla​
only toplevel;   -- no mostrar el sql recursivo ​
​
audit policy nombre_politica​
except usuario_excluido;
```

ejemolo de clase de politicas

```sql
--@Autor:          Jorge A. Rodriguez C
--@Fecha creación:  dd/mm/yyyy
--@Descripción:  Ejemplo de auditoria de administración de PDBs

Prompt ==> Conectando como sysdba en jrcbda_s2
connect sys/system2@jrcbda_s2 as sysdba

Prompt ==> Crear usuario cuyos objetos serán auditados
drop user if exists jorge03_rh cascade;
create user jorge03_rh identified by jorge quota unlimited on users;
grant create table, create session to jorge03_rh;

Prompt ==> Crear tabla auditable de ejemplo y poblarla con datos
create table jorge03_rh.nomina(
  empleado_id number(10,0)
    constraint nomina_pk primary key,
  nombre varchar2(50) not null,
  salario number(10,2) not null
);

insert into jorge03_rh.nomina values (1, 'ana torres', 32000);
insert into jorge03_rh.nomina values (2, 'luis pérez', 28500);
commit;

Prompt ==> crear la política de auditoría
create audit policy pol_auditoria_nomina
  actions insert, update, delete on jorge03_rh.nomina
  only toplevel;

-- Todos los usuarios se auditan excepto el dueño
audit policy pol_auditoria_nomina
  except jorge03_rh;

Prompt ==> Generar actividad sobre la tabla empleando otro usuario
drop user if exists jorge03_consultor_rh cascade;
create user jorge03_consultor_rh identified by jorge quota unlimited on users;
grant create session to jorge03_consultor_rh;
grant select, insert, update, delete on jorge03_rh.nomina to jorge03_consultor_rh;

Prompt ==> Conectando como el usuario que generará la actividad
connect jorge03_consultor_rh/jorge@jrcbda_s2


Prompt ==> Generar actividad sobre la tabla auditable
select * from jorge03_rh.nomina where salario > 30000;
insert into jorge03_rh.nomina values (3, 'carlos gomez', 31000);
update jorge03_rh.nomina set salario = 33000 where empleado_id = 1;
delete from jorge03_rh.nomina where empleado_id = 2;
commit;

Prompt ==> Consultar el rastro de auditoría
-- Lo puede hacer sys, system o cualquier usuario con el rol audit_admin
connect sys/system2@jrcbda_s2 as sysdba
set linesize 200
col event_timestamp format a30
col dbusername format a20
col action_name format a20
col sql_text format a100
/*select event_timestamp, dbusername, action_name, sql_text
from unified_audit_trail
where unified_audit_policies = 'POL_AUDITORIA_NOMINA'
order by event_timestamp;*/

Prompt ==> Limpieza para idempotencia

/* ¿Qué problemas de seguridad  ocurrirían si el usuario que autenticó como
   sysdba deshabilita la política y la borra y después consulta
   la tabla auditada?
*/
noaudit policy pol_auditoria_nomina;
drop audit policy pol_auditoria_nomina;
drop user if exists jorge03_consultor_rh cascade;
drop user if exists jorge03_rh cascade;

exit;


```
