(function(){'use strict';
function create(state,title,notes,context){
 if((state.reports||[]).length>=100)throw Error('Ya tienes 100 reportes. Exporta el seguimiento completo y conserva esa copia antes de iniciar otro archivo de seguimiento. No se borró ningún reporte.');
 const at=new Date().toISOString(),id='CTX-'+at.replace(/[^0-9]/g,'')+'-'+Math.random().toString(36).slice(2,6);
 const snapshot={schemaVersion:1,project:'SENTINEL',updatedAt:at,tasks:SentinelModel.clone(state.tasks),activity:SentinelModel.clone(state.activity)};
 const text=`${id}\n${title}\nFecha: ${at}\nVersión del planificador: 2.0.0\n\nNOTAS DE ESTA SESIÓN\n${notes||'Sin notas adicionales.'}\n\n${context}\n\nCONTINUIDAD Y CODEX\nAgente 4: documenta acuerdos nuevos y decisiones sustituidas sin borrar historia. Identifica tareas modificadas y prepara una orden de cambio para Codex: ID, objetivo, alcance autorizado, módulos/archivos, criterios de aceptación, pruebas, pendientes y próxima acción. No interpretes propuestas como aprobaciones. Antes de programar recordatorios confirma frecuencia, hora y zona America/La_Paz; verifica que realmente se creen. Este reporte está guardado en el dispositivo; para Drive usa Compartir o adjúntalo desde otro chat conectado.\n`;
 const report={id,createdAt:at,title,notes,contextTxt:text,taskSnapshot:snapshot,version:'2.0.0'};
 const next=SentinelModel.clone(state);next.reports=next.reports||[];next.reports.unshift(report);next.updatedAt=at;next.activity.unshift({at,text:'Generado reporte de contexto '+id});next.activity=next.activity.slice(0,2000);SentinelModel.validate(next);return next;
}
function portable(report){return {schemaVersion:1,project:'SENTINEL',updatedAt:report.createdAt,tasks:SentinelModel.clone(report.taskSnapshot.tasks),activity:SentinelModel.clone(report.taskSnapshot.activity),reports:[SentinelModel.clone(report)]};}
window.SentinelReports={create,portable};
})();
