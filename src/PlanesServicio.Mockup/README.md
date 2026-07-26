# Configurador de Servicios y Planes (mockup)

Prototipo estático en **HTML + CSS + JS puro** (sin frameworks ni build step) para configurar
servicios con planes (Básico / Estándar / Premium por defecto), al estilo del boceto: cada
servicio tiene N planes, cada plan tiene un costo y una lista de características, y un plan
superior puede "heredar" todas las características del plan inmediatamente inferior además de
sumar las propias.

## Cómo abrirlo

Es 100% estático: abrí `index.html` en el navegador (doble clic, o `npx serve .` / cualquier
servidor estático). No requiere backend ni instalación.

## Qué incluye

- **Pestaña "Configurar"**: editor tipo Notion. Sidebar con la lista de servicios (arrastrable
  para reordenar) y un tablero de columnas (una por plan) también reordenable por drag & drop.
  Dentro de cada plan, las características son tarjetas que se pueden arrastrar para reordenar
  o mover a otro plan. Todo el texto (nombre del servicio, nombre del plan, precio,
  características) es editable in-line.
- **Herencia de características**: cada plan (salvo el primero) tiene un checkbox "Incluye lo de
  `<plan inferior>`". Si está activo, el plan muestra (en gris, no editables ahí) las
  características del plan anterior más las propias — de forma recursiva, así un plan Premium
  puede heredar de Estándar, que a su vez hereda de Básico.
- **Pestaña "Vista previa (Inicio)"**: la página pública/de inicio que vería un usuario final,
  generada a partir de la misma configuración, con un botón **Pagar / Suscribirme** por plan.
- **Login simulado**: si el botón de pago se presiona sin sesión iniciada, se abre un modal de
  login (mock, sin backend — cualquier correo/contraseña sirve, o el botón "Usar cuenta demo").
  Al iniciar sesión se retoma automáticamente el pago pendiente.
- **Persistencia**: como es un mockup, la configuración se guarda en `localStorage` del
  navegador (simula el "archivo plano"). Los botones **Exportar/Importar** de la barra superior
  permiten bajar/subir esa configuración como un archivo `.json` real. Cuando exista backend, el
  reemplazo natural es: mismo modelo de datos (`servicios[].planes[].caracteristicas[]`) pero
  persistido vía API contra base de datos en lugar de `localStorage`.

## Modelo de datos

```json
{
  "servicios": [
    {
      "id": "srv-tv",
      "nombre": "TV",
      "icono": "📺",
      "planes": [
        {
          "id": "p1",
          "nombre": "Básico",
          "precio": 100,
          "heredaDeInferior": false,
          "caracteristicas": [{ "id": "c1", "texto": "Canales nacionales" }]
        }
      ]
    }
  ]
}
```

- El orden del arreglo `planes` define la jerarquía (índice 0 = plan más bajo). `heredaDeInferior`
  se resuelve contra el plan en `index - 1`, así que reordenar o borrar planes no deja
  referencias colgantes.
- Los archivos exportados con el botón "Exportar" tienen esta misma forma y se pueden volver a
  importar tal cual.

## Pendiente para producción

- Reemplazar `localStorage` + export/import por una API real contra base de datos.
- Reemplazar el login mock por autenticación real.
- Integrar el botón de pago con una pasarela real.
