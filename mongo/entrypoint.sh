#!/bin/bash
set -e

# Generar el archivo keyfile persistente en el volumen configdb si no existe
# Esto evita problemas al recrear contenedores (ya que MongoDB requiere el mismo keyfile)
if [ ! -f /data/configdb/mongo-keyfile ]; then
  echo "==> Generando keyfile persistente..."
  head -c 512 /dev/urandom | base64 | tr -d '\n' > /data/configdb/mongo-keyfile
fi
chmod 400 /data/configdb/mongo-keyfile
chown 999:999 /data/configdb/mongo-keyfile
echo "==> Keyfile persistente listo en /data/configdb/mongo-keyfile."

# Iniciar rutina en segundo plano para inicializar el replica set de forma persistente
(
  echo "==> Inicializador de Replica Set iniciado en segundo plano..."
  
  # Esperar a que MongoDB responda inicialmente en localhost
  for i in {1..30}; do
    if mongosh --port 27017 --quiet --eval "db.runCommand({ping: 1})" &>/dev/null; then
      echo "==> MongoDB está listo y respondiendo en localhost."
      break
    fi
    echo "==> Esperando a que MongoDB inicie... ($i/30)"
    sleep 2
  done

  # Construir argumentos de autenticación si están definidos
  AUTH_ARGS=""
  if [ -n "$MONGO_INITDB_ROOT_USERNAME" ] && [ -n "$MONGO_INITDB_ROOT_PASSWORD" ]; then
    AUTH_ARGS="-u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin"
  fi

  # Bucle de reintentos para evadir la condición de carrera con la inicialización temporal
  echo "==> Iniciando bucle de reintentos para configurar el Replica Set..."
  SUCCESS=0
  for i in {1..20}; do
    # Intentar verificar/inicializar el Replica Set
    # Usamos un flag 'SUCCESS_INIT' o 'SUCCESS_ALREADY_INIT' impreso por JS para validar éxito
    RESULT=$(mongosh --port 27017 $AUTH_ARGS --quiet --eval "
      try {
        var status = rs.status();
        if (status.ok) {
          print('SUCCESS_ALREADY_INIT');
        }
      } catch (e) {
        try {
          var res = rs.initiate({
            _id: '${MONGO_REPLICA_SET_NAME:-rs0}',
            members: [{ _id: 0, host: '127.0.0.1:27017' }]
          });
          if (res.ok) {
            print('SUCCESS_INIT');
          } else {
            print('INIT_FAILED');
          }
        } catch (err) {
          print('WAITING_FOR_BOOTSTRAP');
        }
      }
    " 2>/dev/null || echo "CONNECT_ERROR")

    if echo "$RESULT" | grep -E "SUCCESS_INIT|SUCCESS_ALREADY_INIT" &>/dev/null; then
      echo "==> ¡Replica Set inicializado y activo con éxito!"
      SUCCESS=1
      break
    fi

    echo "==> El Replica Set aún no está listo o está en fase de bootstrap. Reintentando en 3 segundos... ($i/20)"
    sleep 3
  done

  if [ $SUCCESS -eq 0 ]; then
    echo "==> ERROR: No se pudo inicializar el Replica Set después de 60 segundos."
  fi
) &

# Ejecutar el entrypoint oficial de MongoDB heredando todos los argumentos
exec /usr/local/bin/docker-entrypoint.sh "$@"
