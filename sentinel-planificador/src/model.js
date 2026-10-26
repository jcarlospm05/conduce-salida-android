(function(){
'use strict';
const statuses=['Por planificar','Definida','Lista para ejecutar','En ejecución','En revisión','Completada','Bloqueada'];
const clone=x=>JSON.parse(JSON.stringify(x));
function validate(s){
 if(!s||s.schemaVersion!==1||s.project!=='SENTINEL'||!Array.isArray(s.tasks)||!Array.isArray(s.activity))throw Error('El archivo no es un seguimiento SENTINEL compatible.');
 if(s.tasks.length>5000)throw Error('Máximo 5000 tareas.');
 const ids=new Set();
 for(const t of s.tasks){
  if(!t||typeof t.id!=='string'||ids.has(t.id)||!t.id||t.id.length>80)throw Error('IDs ausentes o duplicados.');ids.add(t.id);
  for(const k of ['title','detail','accept','notes','evidence','due','updatedAt','completedAt'])if(typeof t[k]!=='string'||t[k].length>50000)throw Error('Campos de tarea inválidos: '+k);
  if(!t.title.trim()||!Number.isInteger(t.phase)||t.phase<0||t.phase>5||!statuses.includes(t.status)||!['a1','a2','a3'].includes(t.agent)||!['Alta','Media','Baja'].includes(t.priority)||typeof t.optional!=='boolean'||!Array.isArray(t.deps)||t.deps.some(d=>typeof d!=='string'))throw Error('Tarea incompatible: '+t.id);
  if(t.due&&!/^\d{4}-\d{2}-\d{2}$/.test(t.due))throw Error('Fecha inválida.');
  if(t.status==='Completada'&&(!t.evidence.trim()||!t.completedAt))throw Error('Las tareas completadas necesitan evidencia y fecha.');
 }
 for(const t of s.tasks)if(t.deps.some(d=>!ids.has(d)||d===t.id))throw Error('Dependencias inválidas en '+t.id);
 for(const t of s.tasks)if(t.status==='Completada'&&t.deps.some(id=>s.tasks.find(x=>x.id===id).status!=='Completada'))throw Error('La tarea '+t.id+' está completada pero tiene dependencias pendientes. Reabre primero las tareas dependientes.');
 const visiting=new Set(),visited=new Set(),byId=new Map(s.tasks.map(t=>[t.id,t]));
 function visit(id){if(visiting.has(id))throw Error('Dependencias circulares.');if(visited.has(id))return;visiting.add(id);byId.get(id).deps.forEach(visit);visiting.delete(id);visited.add(id);}s.tasks.forEach(t=>visit(t.id));
 if(s.activity.length>10000||s.activity.some(a=>!a||typeof a.at!=='string'||typeof a.text!=='string'))throw Error('Historial inválido.');
 return s;
}
function unresolved(t,tasks){return t.deps.filter(id=>tasks.find(x=>x.id===id)?.status!=='Completada');}
function stats(tasks){const included=tasks.filter(t=>!t.optional),done=included.filter(t=>t.status==='Completada').length;return {total:included.length,done,percent:included.length?Math.round(100*done/included.length):0};}
function saveTask(state,task){const next=clone(state),at=new Date().toISOString();task=clone(task);task.updatedAt=at;const old=next.tasks.find(t=>t.id===task.id);task.completedAt=task.status==='Completada'?(old?.completedAt||at):'';if(task.status==='Completada'&&unresolved(task,next.tasks).length)throw Error('Completa primero las dependencias o actualiza su relación en la tarea.');if(old)next.tasks[next.tasks.findIndex(t=>t.id===task.id)]=task;else next.tasks.push(task);next.updatedAt=at;next.activity.unshift({at,text:`${old?'Actualizada':'Creada'} ${task.id}: ${task.title} → ${task.status}`});next.activity=next.activity.slice(0,2000);validate(next);return next;}
window.SentinelModel={statuses,clone,validate,unresolved,stats,saveTask};
})();
