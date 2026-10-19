# Imagen base: Python 3.12 sobre Alpine (Linux mínimo, ~50 MB)
FROM python:3.12-alpine

# Carpeta de trabajo dentro de la imagen
WORKDIR /web

# Copiar la página al interior de la imagen
COPY index.html .

# Documenta el puerto en el que escucha la aplicación (no publica nada)
EXPOSE 8080

# Programa que arranca el contenedor. 0.0.0.0 = escuchar en todas las interfaces del contenedor
CMD ["python", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
