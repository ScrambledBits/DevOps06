"""API mínima del backend de DevOps06.

Responde en / con el nombre del servidor y el resultado de una consulta a MySQL.
Gunicorn la arranca con "app:app": el módulo app.py y la variable app de abajo.
Las credenciales llegan como variables de entorno desde /etc/devops06-api.env.
"""

import os
import socket

import pymysql
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def estado():
    respuesta = {"backend": socket.gethostname(), "db_host": os.environ["DB_HOST"]}
    try:
        # connect_timeout corto: si el security group bloquea el 3306, la página
        # responde con el error en 3 segundos en lugar de quedarse colgada.
        conexion = pymysql.connect(
            host=os.environ["DB_HOST"],
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            database=os.environ["DB_NAME"],
            connect_timeout=3,
        )
        # El primer with cierra la conexión al salir; el segundo, el cursor.
        with conexion, conexion.cursor() as cursor:
            cursor.execute("SELECT VERSION(), NOW()")
            version, hora = cursor.fetchone()
    except pymysql.MySQLError as error:
        # 503 = servicio no disponible: la API vive, pero su dependencia no responde.
        respuesta.update(db="error", detalle=str(error))
        return jsonify(respuesta), 503
    respuesta.update(db="conectada", mysql_version=version, hora_db=str(hora))
    return jsonify(respuesta)
