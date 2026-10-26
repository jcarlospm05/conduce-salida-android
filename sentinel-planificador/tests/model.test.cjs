const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
global.window=global;for(const f of ['seed.js','model.js','reports.js'])vm.runInThisContext(fs.readFileSync(__dirname+'/../src/'+f,'utf8'));
const M=SentinelModel,s=SENTINEL_SEED;let n=0;
function test(name,fn){fn();console.log('PASS',name);n++;}
test('60 tareas iniciales válidas y 0% ejecutado',()=>{M.validate(s);assert.equal(s.tasks.length,60);assert.equal(M.stats(s.tasks).percent,0);});
test('rechaza ID duplicado',()=>{const x=M.clone(s);x.tasks.push(x.tasks[0]);assert.throws(()=>M.validate(x));});
test('rechaza dependencias inexistentes y circulares',()=>{let x=M.clone(s);x.tasks[0].deps=['missing'];assert.throws(()=>M.validate(x));x=M.clone(s);x.tasks[0].deps=['P02'];x.tasks[1].deps=['P01'];assert.throws(()=>M.validate(x));});
test('completar exige evidencia y dependencias',()=>{let t=M.clone(s.tasks.find(t=>t.id==='D01'));t.status='Completada';assert.throws(()=>M.saveTask(s,t));t.evidence='Aprobado';assert.throws(()=>M.saveTask(s,t));});
test('guardar completa con fecha e historial',()=>{let t=M.clone(s.tasks[0]);t.status='Completada';t.evidence='Acuerdo del propietario';const x=M.saveTask(s,t);assert.ok(x.tasks[0].completedAt);assert.equal(x.activity.length,1);assert.equal(M.stats(x.tasks).done,1);assert.equal(s.tasks[0].status,'Definida');});
test('opcional no cuenta en avance',()=>{const st=M.stats(s.tasks);assert.equal(st.total,59);});
test('exportación JSON conserva notas y tareas',()=>{let t=M.clone(s.tasks[0]);t.notes='Prueba áé ✓';const x=M.saveTask(s,t);assert.deepEqual(M.validate(JSON.parse(JSON.stringify(x))),x);});
test('rechaza fase, agente y estado inválidos',()=>{for(const [k,v]of [['phase',9],['agent','other'],['status','unknown']]){const x=M.clone(s);x.tasks[0][k]=v;assert.throws(()=>M.validate(x));}});
test('importación no elude dependencias',()=>{const x=M.clone(s);const t=x.tasks.find(t=>t.id==='D01');t.status='Completada';t.evidence='Test';t.completedAt=new Date().toISOString();assert.throws(()=>M.validate(x));});
test('no reabre dependencia de tarea completada',()=>{let x=M.clone(s);let p=M.clone(x.tasks.find(t=>t.id==='P02'));p.status='Completada';p.evidence='OK';x=M.saveTask(x,p);let d=M.clone(x.tasks.find(t=>t.id==='D01'));d.status='Completada';d.evidence='OK';x=M.saveTask(x,d);p.status='En revisión';assert.throws(()=>M.saveTask(x,p));});

test('reporte conserva contexto y snapshot sin recursión',()=>{const x=SentinelReports.create(s,'Sesión','Acuerdo nuevo','CONTEXTO');assert.equal(x.reports.length,1);const report=x.reports[0];assert.equal(report.taskSnapshot.reports,undefined);let t=M.clone(x.tasks[0]);t.notes='Cambio posterior';const y=M.saveTask(x,t);assert.notEqual(y.tasks[0].notes,y.reports[0].taskSnapshot.tasks[0].notes);M.validate(SentinelReports.portable(report));});
test('reportes sobreviven exportar e importar',()=>{const x=SentinelReports.create(s,'Sesión','Notas','CONTEXTO');const y=M.validate(JSON.parse(JSON.stringify(x)));assert.deepEqual(x.reports,y.reports);});
test('snapshot recursivo o reporte duplicado se rechaza',()=>{const x=SentinelReports.create(s,'Sesión','','CTX');x.reports[0].taskSnapshot.reports=[];assert.throws(()=>M.validate(x));delete x.reports[0].taskSnapshot.reports;x.reports.push(M.clone(x.reports[0]));assert.throws(()=>M.validate(x));});
console.log(n+' pruebas de modelo aprobadas');
