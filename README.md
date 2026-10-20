# Hefesto Reservas
Agenda privada para empresas de servicios: clientes, profesionales, jornadas, servicios, disponibilidad, reservas, lista de espera, abonos y reembolsos manuales. Interfaz en español, CLP y horarios Santiago.

Ver [docs/INSTALACION.md](docs/INSTALACION.md) para Docker, Coolify, Supabase, importación y preparación Odoo. El sitio usa D1; la instalación portable tiene acceso propio y no depende de ChatGPT.

Incluye código, migración SQL, Docker, cliente compilado en portable/dist, pruebas y exportador. No incluye credenciales ni datos reales.

## Desarrollo
Node 24: `node --test tests/*.test.mjs`. El package.json raíz corresponde a Sites. Para compilar el frontend portable en una copia separada, usa portable/package.json como package.json raíz, instala sus dependencias y ejecuta `npm run build`. Docker realiza ese proceso automáticamente.

## Oferta comercial sugerida
Una instancia privada por negocio, cobrando configuración, carga inicial y soporte mensual. No hay cobro automático de suscripciones. La versión inicial sirve para administración interna; un portal público y roles por profesional requieren desarrollo adicional.

## Despliegue en Coolify (MVP Hefesto)
Coolify publica el `compose.supabase.yaml` detrás de Traefik, que pone TLS y el dominio. Antes del primer arranque:

1. Crear las tablas ejecutando `supabase/migrations/202610130001_hefesto_taller.sql` en el SQL Editor del proyecto Supabase. La versión `202610130001` se comparte con otras apps del mismo kit, así que **no** se aplica con `supabase db push` (la repetida se ignoraría); si choca con otra migración del mismo nombre, renombrar el sufijo numérico y volver a aplicar.
2. Definir las variables del servicio (las obligatorias fallan si faltan):

| Variable | Obligatoria | Notas |
| --- | --- | --- |
| `SUPABASE_URL` | sí con Supabase | URL https pública de Supabase, o `http://supabase-kong:8000` si se enruta por la red interna del kit. |
| `SUPABASE_SECRET_KEY` | sí con Supabase | Clave secreta (`sb_secret_…`). Nunca `sb_publishable_…`. |
| `WORKSHOP_ID` | no | `main` por defecto; identifica la fila en `hefesto_reservas_states`. |
| `ADMIN_PASSWORD` | sí | Mínimo 16 caracteres. |
| `PUBLIC_ORIGIN` | sí | Definirlo a mano con el dominio https asignado en Coolify (p. ej. `https://reservas.ejemplo.cl`). Traefik **no** inyecta variables de entorno. |
| `COOKIE_SECURE` | no | `true` por defecto; `false` solo para pruebas locales. |

Notas operativas adicionales:

- En Coolify, asignar el dominio al servicio `taller` (puerto 3000). `STORAGE_BACKEND` está fijado a `supabase` directamente en `compose.supabase.yaml` y no se configura por variable.
- Si la URL interna `http://supabase-kong:8000` queda detrás del kong de Coolify con un nombre distinto, ajustar la lista de hosts admitidos en `portable/storage.mjs` para incluirlo.
