## Tema 02

45/52

**Recovery**: Proceso que se lanza cuando se detecta que los cambios no estan sincronizados

### Shutdown

pregunta examen: un datafile corrupto

### Ejercicio de clase 4

- A: Generar las sentencias SQL necesarias para mostrar el nombre de la instancia,
  la fecha de inicio a nivel de segundos, el status de la instancia y el status de la
  base de datos, cuando la instancia se encuentre iniciada en modo nomount.

script para iniciar todo rapido

```bash
#!/bin/bash
# @Descripcion  Utilidad para levantar el listener y la instancia de la CDB del
#               contenedor, verificando el estado antes de intentarlo (idempotente).
#               Ubicación sugerida: / dentro del contenedor. Ejecutar como root; el
#               script hace su - oracle internamente para autenticar por sistema
#               operativo en cada operación.

## -- Este script se llama: start-cdb.sh
if [ "$(whoami)" != "root" ]; then
  echo "ERROR: este script debe ejecutarse como el usuario root"
  exit 1
fi

echo "Verificando el listener..."
if su - oracle -c "lsnrctl status" >/dev/null 2>&1; then
  echo "El listener ya esta en ejecucion"
else
  echo "Iniciando el listener..."
  su - oracle -c "lsnrctl start"
fi

echo "Verificando el estado de la instancia..."
estado=$(su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
set heading off feedback off pagesize 0
select status from v\$instance;
exit
EOF
)
estado=$(echo "${estado}" | tr -d '[:space:]')

if [ "${estado}" = "OPEN" ]; then
  echo "La instancia ya esta abierta (OPEN)"
else
  echo "Iniciando la instancia..."
  su - oracle -c "sqlplus -s /nolog" <<EOF
connect / as sysdba
startup
exit
EOF
fi

echo "Cambiando al usuario admin"
exec su - jorge
echo "Listo."
```

ejec

```sql
-- A
startup nomount
-- 
select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;


-- sqlplus sys/system
-- startup nomount para poder ejecutar elste script
-- formateo
set linesize window;
col instance_name format a20;
col startup_time format a20;
col status format a10;
col database_status format a15;
run -- ejecuta la ultima sentencia SQL
```

- B: Cambiar el status de la instancia a mounted y ejecutar nuevamente la consulta
  del punto anterior.

```sql
alter database mount;
select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;
-- status ahora debe ser mount
```

- C: Repetir los 2 pasos anteriores hasta abrir la base de datos — analizar los
  resultados.

```sql
alter database open;
select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;
```

- D: Con la base de datos abierta, mostrar el valor del parámetro undo_tablespace a
  nivel de sesión y a nivel de instancia. ¿Coinciden ambos valores? ¿Por qué?

```sql
-- A
startup nomount
-- Consulta
select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;

---B
alter database mount;
-- misma consulta anterior

--C
alter database open;
-- misma consulta anterior

--D parámetro undo_tablespace a nivel session
show parameter undo_tablespace;

--- A nivel instancia
select value from v$system_parameter 
where name = 'undo_tablespace';
```

- E: Cerrar la base de datos con alter database close. Revisar el status de la
  instancia — con base a este valor, ¿qué otra instrucción SQL permitiría cerrar
  una base de datos?

```sql
alter database close;
elect instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;
-- se ve que regresa al estado mount
```

- F: Detener la instancia. Abrirla en modo de solo lectura y ejecutar sentencias SQL
  para demostrarlo. Después, detener la instancia con el modo abort.

```sql
shutdown immediate;
startup mount;
alter database open read only;
--
select instance_name,
  to_char(startup_time, 'yyyy/mm/dd hh24:mi:ss') startup_time,
  status, database_status
from v$instance;

-- debe mostrar estatos open y active
-- si se trata de crear un atabla
-- ORA-16000: Attempting to modify database or pluggable database that is open for
```

- G: Un equipo de aplicaciones reporta transacciones largas en curso, y se necesita
  aplicar un parche de emergencia en los próximos 5 minutos, sin posibilidad de
  esperar a que esas transacciones concluyan de forma natural. ¿Qué modo de
  shutdown es el más adecuado para esta situación y por qué? ¿Qué diferencia
  práctica tendría frente a immediate?

```sql
-- seleccionamos abort
shutdown abort;
```

- sdsds

# privilegios

Los hay de:

- sistema: create ---

- objeto:  permisos para operaciones DML sobre lo sobjetos del usuario

Ejericicio de clase pp 52/52



M.​ Un usuario con el privilegio create restricted session podría autenticarse durante
startup restrict aunque el resto de los usuarios no pueda. ¿Ese mismo usuario
podría autenticarse mientras la base de datos está suspendida (sin restrict), bajo
las mismas condiciones que un usuario sysdba? Justificar la respuesta con base en
qué archivos necesita leer cada mecanismo.

R: En modo restringido no tien equ ever con suspendido, va a dejar acceder aa los usuarios, que no necesiten acedo a los archivos ( archivo de passwords, sistema operativo )
