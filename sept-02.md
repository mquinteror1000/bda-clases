# tema 02 Instalacion y con de una BD

##  loop devices
- se usan del lado del host
- archivos binarios que se pueden montar en una ruta
## volumenes docker
 - Bind Mount: hay una correspondencia entre una carpeta del host y una carpeta en el host
 ```bash
 -v /ruta_host/:/ruta_contenedor/
 ```
 - Volumne nombrado: Es manejado por docker en una carpeta especial
 ```bash
 -v <nombre>:/opt/oracle/oradata
 ```

CArpeta
```bash
${UNAM_HOME}/disk-images
dd -if=/dev/zero of=disk1.img bs=100M count=10
dd -if=/dev/zero of=disk2.img bs=100M count=10
dd -if=/dev/zero of=disk3.img bs=100M count=10

# asociar archivo binario a un loop device
losetup -fP disk1.img
# verificar que estan asignados 
losetup -a
mkfs.ext4 disk1.img
mkfs.ext4 disk2.img
mkfs.ext4 disk3.img

# montar los dispositivos
# se montan en la la ruta
mkfir -p 4{UNAM_HOME}/bda/diskc/d01   # en uno de estos estarán los redologs
# montar 
mount -o loop /dev/loop0 ${UNAM_HOME}/bda/disks/d01   # es temporal
# usar /etc/fstab
mount -o loop /dev/loop0 ${UNAM_HOME}/bda/disks/d01 # entrada de fstab
mount -a
# particiones montadas en ${UNAM_HOME/bda}
df -h | grep "${UNAM_HOME}/bda/*"
# salida

```
### Paso 4: Creacion del archivo de passwords
```sql
$ORACLE_HOME/dbms/orapw${ORACLE_SID}

```
#### Sesin en line VS Code
practicas scripts

### Paso 5 Creacion del archivo de parametros

Almacenado en

${HORACLE_HOME}/dbs

- pfile: **binario**: spfilefree.ora
- spfile: **texto**: initfree.ora ; podemos modificar; parametro=valor
- init.ora : Es solo una plantilla

**uando se hace startup, implicitamene se lee este archivo**

Podríamos levantar con un archivo de parametros personalizado
```bash
startup pfile="/opt/oracle/oradata/FREE/myparamfile.ora"
```
**dbname:** free
**dbdomain:** fi.unam

#### script que crea el pfile
Compartido

### paso 6 Crear sppfile
Haciendo uso de sqlplus
```bash
sqlplus sys/Hola1234* as sysbda
create spifile from pfile
```
### Paso 7 Crear
Practica  6
practicas/06/s-01-crea-spfile-ordinario.sql
y p
### Paso 7 Crear directorios para la nueva CDB
cuando se genera la base de datos
se van a generar, redologs, datafiles ...
Por eso es necesario crear los directorios

practicas/06/s-02-crea-directorios-root.sh
 ## Como monitorear el script
 del scropt s-04-crea crea diciconario de datos
 ```bash
ls -ltr  /tmp/dd-logs
# otra forma de monitorear archivos
tail -f archivo
 ```

## 09 sep

Usuarios administradores son para cada pdb

**s03-creacion de cdb**

```sql

```


**Peldaños de la base**
- nomount
- nount
- open

## Administracion de parámetros
**1 Archivo de parámetros para la CDB, no para cada pdb**
- **spifile**: Binario
- **pfile**: de texto
Desde la memoria
```sql
create pfile from memory
```
**PUeden definrse a varios niveles**
1. Spfile
2. Instancia: memory
3. PDB
4. Sesion

Puede haber parametros que pueden tener valores direrenes y otros que si permiten
- dbname : Debe ser igual a todos los niveles
- date_format: pude cambiarse a nivel incluso de sesión

## PArámetros básicos
Parámetros


#### Modificacion de parámetros
- Parámmetros dinámicos: Toman efecto en el instante
- Parámtros estáticos: REwquieren el reinicio

#### Instruccion para hacer un cambio
para hacer un cambio
```sql
alter sstem set <parametro=valor> [container={current}]
 [scope={spfile}];
 alter seccion set parametro=valor;
```

#### reset de un parametro
reset
```sql
alter system reset parametro scope = spfile;
```
both, spfile o session depende de la naturaleza del parámetro
- isses_modifiable: TRUE -> se puede cambiar por sesion
- isis_moifiable:
    - immediate: TRUE El cambio toma efecto de forma inmediata, FALSE; Requiere un inicio
    - deferred: cambios en la sesion, requiere reinicio de la sesion: logout login
    - false:
- ispdm_modifiable : modificable por la pdb

### current / all
- container = current, permite a las pdb tener sus propias versiones de los parametros, con container = current 
- all hace que se propague la version de la cdb a todas las cdb
