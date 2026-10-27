import test from 'node:test';
import assert from 'node:assert/strict';
import {availability,slots,minutes,clock,active,stages} from '../lib/domain.ts';

// Chile (America/Santiago) cambia de hora el primer sabado de abril y de septiembre.
// En esas fechas la medianoche local existe o no existe: cualquier calculo que
// use la medianoche local puede correrse un dia. El dominio debe decidir el dia
// de la semana desde el mediodia UTC, que es lo que hace availability().
const base={professionals:[{id:'p1',name:'Antonia',specialty:'Estilista',serviceIds:['s1'],start:'09:00',end:'19:00',days:[1,2,3,4,5,6],active:true}],
  services:[{id:'s1',name:'Corte',category:'Peluqueria',duration:45,buffer:15,price:22000,deposit:5000,active:true}],
  bookings:[],blocks:[],waitlist:[],audit:[]};

test('los helpers de hora y turno son coherentes',()=>{
  assert.equal(minutes('09:30'),570);
  assert.equal(minutes('00:00'),0);
  assert.equal(clock(570),'09:30');
  assert.equal(clock(0),'00:00');
  assert.equal(clock(1439),'23:59');
});

test('el domingo se rechaza aunque sea el dia del cambio de hora de abril',()=>{
  // 2026-04-05 es domingo y ademas el dia en que Chile adelanta el reloj.
  assert.throws(()=>availability(base,'p1','2026-04-05','10:00',45,15),/trabaja ese d|Fecha u hora/i);
});

test('el domingo se rechaza el dia del cambio de hora de septiembre',()=>{
  // 2026-09-06 es domingo y el dia en que Chile atrasa el reloj.
  assert.throws(()=>availability(base,'p1','2026-09-06','10:00',45,15),/trabaja ese d|Fecha u hora/i);
});

test('el sabado sigue disponible en los dias de cambio de hora',()=>{
  assert.doesNotThrow(()=>availability(base,'p1','2026-04-04','10:00',45,15));
  assert.doesNotThrow(()=>availability(base,'p1','2026-09-05','10:00',45,15));
});

test('la semana laboral no se corre un dia alrededor de los cambios de hora',()=>{
  // Domingo de cada fecha: debe seguir rechazada. Dia de labor: debe seguir abierto.
  const domingos=['2026-03-01','2026-04-05','2026-09-06','2026-11-01'];
  const laborales=['2026-03-03','2026-04-04','2026-09-05'];
  for(const fecha of domingos){
    assert.throws(()=>availability(base,'p1',fecha,'10:00',45,15),/trabaja ese d|Fecha u hora/i,fecha+' debe seguir siendo domingo');
    assert.deepEqual(slots(base,'s1','p1',fecha),[],fecha+' no debe ofrecer horarios');
  }
  for(const fecha of laborales){
    assert.ok(slots(base,'s1','p1',fecha).length>0,fecha+' debe ofrecer horarios');
  }
});

test('la disponibilidad respeta la jornada, el margen y las reservas existentes',()=>{
  assert.throws(()=>availability(base,'p1','2026-03-03','08:00',45,15),/Horario fuera de jornada/);
  assert.throws(()=>availability(base,'p1','2026-03-03','19:00',45,15),/Horario fuera de jornada/);
  const conReserva={...base,bookings:[{id:'b1',customerId:'c1',serviceId:'s1',professionalId:'p1',date:'2026-03-03',time:'10:00',duration:45,buffer:15,status:'Confirmada',payments:[]}]};
  assert.throws(()=>availability(conReserva,'p1','2026-03-03','10:30',45,15),/se superpone/);
  assert.doesNotThrow(()=>availability(conReserva,'p1','2026-03-03','11:15',45,15));
});

test('una reserva cancelada no bloquea el horario',()=>{
  const cancelada={...base,bookings:[{id:'b1',customerId:'c1',serviceId:'s1',professionalId:'p1',date:'2026-03-03',time:'10:00',duration:45,buffer:15,status:'Cancelada',payments:[]}]};
  assert.doesNotThrow(()=>availability(cancelada,'p1','2026-03-03','10:00',45,15));
});

test('slots no ofrece un servicio que el profesional no presta',()=>{
  assert.deepEqual(slots(base,'s1','p2','2026-03-03'),[],'p2 no ofrece s1');
  assert.deepEqual(slots(base,'s2','p1','2026-03-03'),[],'p1 no ofrece s2');
});

test('los estados de la reserva son los que la UI documenta',()=>{
  assert.deepEqual(stages,['Pendiente','Confirmada','En atención','Completada','No asistió','Cancelada']);
  assert.equal(active({status:'Confirmada'}),true);
  assert.equal(active({status:'Cancelada'}),false);
  assert.equal(active({status:'No asistio'}),false);
});
