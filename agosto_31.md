# Tema 2
## 31 agosto 2026
```bash
# ver particiones
df -h

sudo blockdev --getbsz /dev/sda7
# 4096 = 4k
# bd Recomienda 8K
```
En la base de datos
estando en sys
```sql
show parameter db_blocksize
```
se recomienda que el tmaño del bloque para los redologs
sea pequeño porque lee mucho y en cantidades pequeñas
**recomendado:** 512bytes

```sql
-- espacio desperdiaciado
select name, value from v$sysstat where name = 'REDO WASTAGE';
```
### Tablespaces
- users
- system
- temp
- sysaux
- undo


( si ocupo un windows en VM, pero con el espacio compartido, con un podman, un samba y montarlo en el windows )
### Opciones para manejar los volumenes en los contenedores de docker
 - Volumenes nombrados
 - bind mount

Volumen nombrado
```bash
# Permite eliminar el contenedor sin perder los datos
```

Bind Mount
```

# los administra docker
```

