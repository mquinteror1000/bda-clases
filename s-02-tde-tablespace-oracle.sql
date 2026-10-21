--@Autor:          Jorge A. Rodriguez C
--@Fecha creación:  dd/mm/yyyy
--@Descripción:  Ejemplo de  cifrado de tablespaces

Prompt ==> Conectando como sysdba en cdb$root
connect sys/system2 as sysdba

Prompt ==> Configurando parámetros de cifrado
--directorio raíz del wallet
alter system set wallet_root='/opt/oracle/admin/free/wallet' scope=spfile;

Prompt ==> Reiniciando ..
shutdown immediate;
startup;

Prompt ==> Configurando TDE
alter system set tde_configuration='keystore_configuration=file' scope=both;

Prompt ==> Creando wallet (Keystore) y clave maestra

-- Crea el keystore (wallet) en el directorio wallet_root definido arriba.
administer key management create keystore identified by "system2";

-- Genera la clave maestra en el keystore actualmente abierto para el
-- contenedor actual (cdb$root) y todos los PDBs.
-- identified by indica la contraseña del keystore arriba definida.
administer key management set keystore open identified by "system2";

--  Genera un respaldo del keystore (Archivo p12) con timestamp.
-- Estos backups son importantes por si se quiere leer una versión anterior,
-- en especial cuando se hace rotación de clave maestra (rekey). Con esto
-- es posible tener acceso a versiones anteriores de la clave maestra requerida
-- para cifrar/descifrar datos antes de la rotación.
administer key management set key identified by "system2" with backup;

Prompt ==> Crear un keystore auto-login local

--Permite abrir la BD automáticamente sin necesidad de ingresar la
--contraseña del keystore.
administer key management create local auto_login keystore
  from keystore identified by "system2";

--verificar el estado del keystore
set linesize 200
col wrl_type format a15
col wrl_parameter format a40
col status format a10
col wallet_type format a15
select * from v$encryption_wallet;

Pause "==> Verificar el estado del keystore, [Enter] para continuar"
-- Notar que el keystore está abierto en cdb$root y cerrado en el PDB.

prompt ==> Conectando como sysdba en jrcbda_s2
alter session set container = jrcbda_s2;


-- Modo united: el keystore es compartido, pero cada PDB debe abrirlo y fijar
-- su propia clave maestra (container = current) antes de poder cifrar aquí.
-- Sin esto: ORA-46658 (keystore cerrado) u ORA-28361 (falta la clave maestra).
administer key management set keystore open identified by "system2" container = current;
administer key management set key identified by "system2" with backup container = current;

prompt ==> Crear tablespace cifrado y tabla en él
create tablespace ts_rh_cifrado
  datafile '/opt/oracle/oradata/FREE/jrcbda_s2/ts_rh_cifrado01.dbf' size 50m
  encryption using 'aes256'
  default storage (encrypt);

prompt ==> Creando usuario, tabla y datos de ejemplo en el tablespace cifrado

drop user if exists jorge032_rh cascade;
create user jorge032_rh identified by jorge
  default tablespace ts_rh_cifrado
  quota unlimited on ts_rh_cifrado
  quota unlimited on users;
grant create table, create session to jorge032_rh;

create table jorge032_rh.nomina_cifrada (
  empleado_id number primary key,
  nombre      varchar2(60),
  salario     number(10,2)
) tablespace ts_rh_cifrado;

insert into jorge032_rh.nomina_cifrada values (1, 'ana torres', 32000);
commit;

prompt ==> Creando una tabla en tablespace no cifrado y poblarla con datos
create table jorge032_rh.nomina_no_cifrada (
  empleado_id number primary key,
  nombre      varchar2(60),
  salario     number(10,2)
) tablespace users;
insert into jorge032_rh.nomina_no_cifrada values (1, 'ana torres', 32000);
commit;

prompt ==> Forzar escritura a datafiles
alter system checkpoint;

prompt ==> Consultando la tabla cifrada
select * from jorge032_rh.nomina_cifrada;

prompt ==> Consultando la tabla no cifrada
select * from jorge032_rh.nomina_no_cifrada;
pause "==> Presione [Enter] para continuar"

Prompt ==> Buscar el dato en el datafile del tablespace  no cifrado con el comando `strings` de Linux
!strings /opt/oracle/oradata/FREE/jrcbda_s2/users01.dbf | grep  -i "ana torres"

Prompt ==> Validar que los datos están cifrados en datafile con el comando `strings` de Linux
!strings /opt/oracle/oradata/FREE/jrcbda_s2/ts_rh_cifrado01.dbf | grep  -i  "ana torres"


Prompt ==> Limpieza para  TS y usuarios.
-- La configuración del keystore y la clave maestra se mantiene para poder
-- abrir la BD sin intervención.
drop user jorge032_rh cascade;
drop tablespace ts_rh_cifrado including contents and datafiles;

exit;

