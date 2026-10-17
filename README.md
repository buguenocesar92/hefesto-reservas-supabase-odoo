# Hefesto Reservas
Agenda privada para empresas de servicios: clientes, profesionales, jornadas, servicios, disponibilidad, reservas, lista de espera, abonos y reembolsos manuales. Interfaz en español, CLP y horarios Santiago.

Ver [docs/INSTALACION.md](docs/INSTALACION.md) para Docker, Coolify, Supabase, importación y preparación Odoo. El sitio usa D1; la instalación portable tiene acceso propio y no depende de ChatGPT.

Incluye código, migración SQL, Docker, cliente compilado en portable/dist, pruebas y exportador. No incluye credenciales ni datos reales.

## Desarrollo
Node 24: `node --test tests/*.test.mjs`. El package.json raíz corresponde a Sites. Para compilar el frontend portable en una copia separada, usa portable/package.json como package.json raíz, instala sus dependencias y ejecuta `npm run build`. Docker realiza ese proceso automáticamente.

## Oferta comercial sugerida
Una instancia privada por negocio, cobrando configuración, carga inicial y soporte mensual. No hay cobro automático de suscripciones. La versión inicial sirve para administración interna; un portal público y roles por profesional requieren desarrollo adicional.
