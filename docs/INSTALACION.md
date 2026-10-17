# Instalación de Hefesto Reservas

## Docker / Coolify con Supabase
1. Crea o elige un proyecto Supabase.
2. Ejecuta `supabase/migrations/202610130001_hefesto_taller.sql`. El nombre heredado del archivo no afecta las tablas exclusivas: hefesto_reservas_states y hefesto_reservas_sessions.
3. Copia `.env.example` a `.env`. Completa SUPABASE_URL, SUPABASE_SECRET_KEY (sb_secret o service_role), WORKSHOP_ID (instancia), ADMIN_PASSWORD (16 caracteres mínimo), PUBLIC_ORIGIN (dominio HTTPS), COOKIE_SECURE=true.
4. Ejecuta `docker compose -f compose.supabase.yaml up -d --build`. En Coolify selecciona ese Compose y asigna dominio al puerto interno 3000.
5. Accede con la contraseña de administración. La clave Supabase nunca se entrega al navegador.

El nombre del servicio Compose `taller` y WORKSHOP_ID se conservan del adaptador. Son exclusivos de esta instalación y las tablas están separadas de otros productos Hefesto. Si instalas varios productos en el mismo servidor, asigna distintos dominios y puertos de host: cambia 3080 según corresponda.

## SQLite sin Supabase
`docker compose -f compose.yaml up -d --build`. Usa volumen persistente. En pruebas locales configura PUBLIC_ORIGIN=http://localhost:3080 y COOKIE_SECURE=false; en producción HTTPS y cookie segura. Los datos empiezan vacíos. Crea servicios, profesionales, clientes y luego reservas.

## Migración desde el sitio
Exporta JSON en Portabilidad; el ZIP de código no incluye registros reales.

```
docker compose -f compose.supabase.yaml cp hefesto-reservas.json taller:/data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs validate /data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs import /data/import.json
```

El importador preserva IDs y rechaza sobrescribir instancias con datos. Usa un WORKSHOP_ID nuevo o volumen vacío. Detén operaciones durante la migración. Para exportar: `node portable/tools/transfer.mjs export /data/respaldo.json` dentro del servicio; copia el archivo fuera. Guarda respaldos independientes protegidos.

## Preparación para Odoo
`python3 migration/prepare_odoo.py hefesto-reservas.json salida-odoo`

CSV de contactos, servicios, profesionales, reservas y pagos para conciliación. JSON íntegro para bloquear horarios, lista de espera e historial. Mapear campos y estados según versión y módulos destino. No incluye addon ni sincronización automática. Probar en base de ensayo. Horarios America/Santiago: no convertir usando un desfase UTC fijo.

## Flujo
1. Crear servicios con duración, margen, precio y abono.
2. Crear profesionales con servicios y días laborales.
3. Registrar clientes y elegir un horario disponible.
4. Registrar abono recibido y confirmar; iniciar atención, registrar saldo y completar.
5. Cancelaciones e inasistencias liberan horario, pero conservan abonos. Reembolsar fuera de la app y registrar referencia si corresponde.
6. Bloqueos requieren reprogramar antes las reservas activas que se superponen. La lista de espera requiere asignación manual; no hay avisos automáticos.

Precio, duración y abono quedan fijados en cada reserva. La reprogramación conserva esos valores. Los horarios incluyen margen y se validan al guardar. Las reservas completadas conservan su espacio histórico. Se permite registrar fechas pasadas para regularización administrativa. El archivo .ics permite importar una cita al calendario; no se sincroniza y puede requerir revisar zona horaria en el cliente de calendario.

## Alcance y verificación
- Acceso único de administración; profesionales son registros, sin login individual. Sin portal público.
- Pagos y reembolsos manuales, sin pasarela, SII ni conciliación bancaria automática.
- No conecta WhatsApp, correo ni calendarios externos.
- Servicios, profesionales y clientes se crean; esta versión no incluye edición o baja desde la interfaz. Revisar los datos antes de crearlos.
- Una jornada continua por profesional; descansos con bloqueos por fecha. Sin reservas grupales o recurrentes.
- Supabase usa documento JSON por instancia y sesiones, con RLS y acceso exclusivo servidor; no Supabase Auth ni tablas normalizadas por entidad.
- Seis pruebas automáticas de dominio y API portable aprobadas. Compilación y tipos verificados. Docker y un Supabase real requieren prueba en destino; QA visual en navegador pendiente.
