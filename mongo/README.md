# MongoDB Local Replica Set con Mongo Express

Este repositorio contiene la configuración completa en Docker Compose para levantar un entorno local de MongoDB con un **Replica Set** de un solo nodo (`rs0`) y **Mongo Express** como interfaz gráfica de administración.

Esta configuración es ideal para el desarrollo local, ya que permite el uso de características avanzadas de MongoDB como **Transacciones**, **Change Streams** y soporte nativo para ORMs modernos como Prisma, sin el consumo excesivo de recursos de un Replica Set multi-nodo.

---

## 🚀 Cómo Iniciar el Entorno

1. **Asegúrate de tener Docker Desktop activo.**
2. Abre una terminal en este directorio.
3. Ejecuta el siguiente comando para levantar los servicios en segundo plano:
   ```bash
   docker compose up -d
   ```

El contenedor `mongodb-local` iniciará un script en segundo plano que esperará a que el servidor de MongoDB responda y luego inicializará el replica set de forma automática (`rs.initiate()`). En los siguientes inicios de Docker, detectará que ya está inicializado y omitirá la configuración inicial.

---

## 🛠️ Credenciales y Accesos

Toda la configuración sensible está contenida en el archivo `.env`. Por defecto:

* **Administrador de MongoDB**:
  * **Usuario**: `admin`
  * **Contraseña**: `adminpassword`
  * **Puerto**: `27017`
  * **Nombre del Replica Set**: `rs0`

* **URL de Conexión (Connection String)** para tus aplicaciones locales (Prisma, Mongoose, NestJS, etc.):
  ```env
  mongodb://admin:adminpassword@localhost:27017/mi_base_de_datos?replicaSet=rs0&authSource=admin
  ```

* **Interfaz de Mongo Express**:
  * **Dirección**: [http://localhost:8081](http://localhost:8081)
  * **Usuario**: `admin`
  * **Contraseña**: `adminpassword`

---

## 🔍 Cómo Verificar el Estado del Replica Set

Puedes comprobar el estado de salud y miembros del replica set ejecutando el comando `rs.status()` dentro del motor de base de datos con el siguiente comando:

```bash
docker exec -it mongodb-local mongosh -u admin -p adminpassword --eval "rs.status()"
```

Busca en la salida el campo `"ok": 1` y asegúrate de que el miembro tenga la propiedad `"stateStr": "PRIMARY"`.

---

## 🛑 Cómo Detener el Entorno

Para detener los contenedores y mantener los datos guardados:
```bash
docker compose down
```

Si deseas reiniciar el entorno desde cero, eliminando todos los datos almacenados en la base de datos:
```bash
docker compose down -v
```
