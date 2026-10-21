## 14 de septiembre de 2026

REsolución de ejercici en clase

Mostrar parametros de la sesion

```sql
show parameters nls_date_format;
-- cambiar el fromato de feca hora
alter session set nls_date_format='dd/mm/yyyy 524:mi:ss';
select sysdate from dual
select sysdate; -- para las nuevas versiones
```

Procesess t-02 pp 40/50

```sql
-- cambiar a 300 el valor de procesess 
-- por la naturaleza del parámeto solo puede hacerse desde cdb$root
--actualmente tiene
show parameters procecess;
-- aparecen varios y asta abajo 
-- procecss
alter sesison set container=cdb$root;
show parameters prosecess;
alter system ser processes=300; -- ahorata va sin container y sin scope
-- el valor por defecto de scope es both
-- documentacion dice; por defecto both si se inicio con spfile
-- memory si se inición con pfile ( ya que no puede modificar el spfile )

-- scope por defecto current
-- que pasa
show spparameters processes;
-- hacer el cambio
alter  set system set processes=300 scope=spfile; -- con esto es permanente
show parameter processes;

-- como es dinamico para y quisiera que tome efecto se puede 
alter system set processes=300; -- lanza un errorar 

--regresar el valor que tenia
alter system reset processes scope=spfile;
show parameters processes;

-- java jit ebable;  es un booleano
-- si encendido; permite ejecutar just in time compiler; par aejecutar las apps java mas rapido
-- por defecto está en true
-- naturaleza; dinamico, a nivel sesion

-- deshabilitar el compilador a nivel sesiónn
-- ver que tiene en la session
show parameter java_jit_enable; -- da true; el valor por defecto
-- deshabilitarlo
alter sesison set java_jit_enabled=false; -- funciona a novel seseion 
show parameter java_jid_anebled;
-- en value aparece vacio por que no esta en el spfile; i.e no se ha hecho permanente
-- si consiltar a nivel instancia
select value from v$system:parameter where name='java_jit_enabled'; -- devuelve true
-- Que valor tendra el parametro sí se abre una nueva sesion
-- desde una nueva terminal
-- dockerBda2T 
-- su -l jorge
-- sqlplus sys/system2 as sysdba
show parameter java_jit_enabled;
-- D mostrar el parametro a nivel instalncia;  tenia true
-- e parametro a nivel instancia
-- f deshabilitar compilador a nivel instancia y habilitarlo a nivel sesion
alter session set java_jit_enabled=true;
alter system set java_jit_enabled=false scope=memory; -- para deshabilitar a nivel instancia
-- g comprobar el serultado a nivel sesion
show parameter java_jit_enabled;
-- comprobar el resultado de f) en una sesion difrente
-- si en la sesion vuelvo a habilitarlo 
show parmeter java_jit_enabled;

-- open_cursorss oermite ejecutar muchas sentencias sql al mismo tiempo
-- no se puede modificar a nivel sesion
conectarse a la otra 
-- dockerBda2T
--su -l jorge

sqlplus sys/system2@jrcbda_s2 as sysdba;
-- ROOT
show parameter open_cursors; -- da 50
-- PBD
show parameter open_cursor; -- da 50
-- ROOT
alter system set oen_cursors=60 container=current scope=spfile; 
-- reiniciar para que los cambios ocurran
--ROOT
shutdown immadiate;
startup
show parameter open_cursors; -- nivel sesion

--PDB 
show parameter open_cursors; -- da 60 es el valor jeedado de root
-- en la pdb modificar a 70
-- PDB
alter system set open_cursors=70 container=current sope=spfile; -- si lo permitió

-- en T1 
-- ROOT
shutdown immediate
startup

-- PDB
--volver a iniciar sesion a la instancia
-- consltar el calor


-- Root
show parameter open cursors; 60


--PDB
show patemeter open_cursors; -- 70
show spparameter open_cursors; -- 70

-- g) 
-- ROOT
aler system ser open_cursors=80 container=all scope=spfile;
-- reiniciar


-- CDB 
-- inciar sesion
show parameter open_cursors;
show spparameter open_cursors;
-- como se cambio con container=all modificón en todas las pdb

-- i)
-- PDB
alter system set ioen_cursors=container=current scope=spfile


--ROOt
-- reiniciar


-- PDB
show parameter open_cursors; -- da 90
shown spparameter open_cursors; -- da 90

-- ahora Root les permite
-- ROOT cambia a 100
-- reinica sesion
show parameter open_cursors; -- 100
--PDB
show parameter open_cursors ; -- da 90
show spparameter open_cursors; -- da 90


--- PARA dejar como estaba
-- ROOT
alter system sreset open_cursors container=all scope=spfile; -- tras el reinicio vuelve al parámetro por defecto
-- CDB
alter system reset open_cursors scope=spfile;
```

De la práctica 4

cuando se crean usuarios en  ROOT

**Common users**: c##usuarioglobal

## 2.7 Startup y shutdown de una BD

Pude iniciarse con un archivo pfile en una ruda distinta a la ubucación por defecto

- nomount: Solo crea las areas de memoria y  los procesos de la instancia
  
  - Sirve para:  reparar errores de parámetros, crear BD nuevas, corregir algo que impide hacer mount.
  
  - Requiere: 
    
    - Archivo de parámetros ( spfile ) en el orden
      
      - spfile{oracle_SID}.ora; Archivo de parámetros binario
      
      - spfile.ora
      
      - init{ORACLE_SID}.ora; Archivo de parámtros de texto
  
  - Puede:
    
    - sds

- mount
  
  - sirve para: 
  
  - Requiere
    
    - **archivos de control**: Permite unir la instancia con la CDB

Ejercicio

```sql
-- shutdown
-- SO
export ORACLE_SID=NOSE

sqlplus / as sysdba
startup; -- falla
-- se resuelve vilviendo a colocar el FREE en ORACLE_SID
```
