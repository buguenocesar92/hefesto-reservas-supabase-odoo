"""CSV de preparación: mapear y validar en Odoo antes de importar."""
import csv,json,sys
from pathlib import Path
if len(sys.argv)!=3:raise SystemExit('Uso: python3 migration/prepare_odoo.py respaldo.json salida')
p=json.loads(Path(sys.argv[1]).read_text());s=p.get('state',p)
if s.get('format')!='hefesto-reservas':raise SystemExit('Formato incompatible')
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
def save(name,columns,rows):
 with (out/name).open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.writer(f);w.writerow(columns);w.writerows(rows)
save('01_contactos.csv',['ID externo','Nombre','Correo','Teléfono'],[['hefesto_customer_'+x['id'],x['name'],x['email'],x['phone']] for x in s['customers']])
save('02_servicios.csv',['ID externo','Nombre','Categoría','Precio CLP','Duración min','Margen min','Abono CLP'],[['hefesto_service_'+x['id'],x['name'],x['category'],x['price'],x['duration'],x['buffer'],x['deposit']] for x in s['services']])
save('03_profesionales_revision.csv',['ID externo','Nombre','Especialidad','Servicios referencia','Inicio','Fin','Días 0 domingo'],[['hefesto_professional_'+x['id'],x['name'],x['specialty'],';'.join('hefesto_service_'+i for i in x['serviceIds']),x['start'],x['end'],';'.join(map(str,x['days']))] for x in s['professionals']])
save('04_reservas_revision.csv',['ID externo','Cliente referencia','Servicio referencia','Profesional referencia','Fecha Santiago','Hora Santiago','Duración min','Estado','Precio CLP','Pagado neto CLP'],[['hefesto_booking_'+x['id'],'hefesto_customer_'+x['customerId'],'hefesto_service_'+x['serviceId'],'hefesto_professional_'+x['professionalId'],x['date'],x['time'],x['duration'],x['status'],x['price'],sum(p['amount'] for p in x['payments'])] for x in s['bookings']])
save('05_pagos_conciliacion.csv',['ID','Reserva referencia','Fecha ISO','Monto CLP','Método','Referencia'],[[p['id'],'hefesto_booking_'+b['id'],p['date'],p['amount'],p['method'],p['reference']] for b in s['bookings'] for p in b['payments']])
(out/'respaldo_completo.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
(out/'LEEME.txt').write_text('Archivos de preparación, no sincronización ni addon. Mapear campos y relaciones en la versión y módulos de Odoo del destino. Probar primero en una base de ensayo. Pagos solo para conciliación: no crean asientos. Días 0=domingo. Fechas y horas de reservas en America/Santiago: convertir con la zona horaria, no usar desfase UTC fijo. Bloqueos, lista de espera e historial completos en JSON.\n')
print('Exportación preparada:',out)
