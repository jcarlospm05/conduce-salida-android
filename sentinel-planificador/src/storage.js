(function(){
'use strict';
const key='sentinel-project-tracker-v1';let warning='',baseline=null,blocked=false;
function load(){let raw=null;try{raw=localStorage.getItem(key);baseline=raw;if(raw)return SentinelModel.validate(JSON.parse(raw));}catch(e){
 if(raw!==null){try{localStorage.setItem(key+'-rejected-recovery',raw);warning='El estado anterior no pudo abrirse. Se conservó una copia recuperable; puedes exportarla desde Cómo continuar. '+e.message;}catch{blocked=true;warning='No se pudo abrir ni respaldar el estado previo. Se bloqueó la sobrescritura para conservarlo. Exporta cualquier cambio de esta sesión y revisa el almacenamiento.';}}
 else{blocked=true;warning='El almacenamiento no está disponible. Exporta JSON antes de cerrar; los cambios no se guardarán automáticamente.';}
 }return SentinelModel.clone(SENTINEL_SEED);}
function save(state){try{
 if(blocked)throw Error('El guardado está bloqueado para proteger los datos previos.');
 if(localStorage.getItem(key)!==baseline)throw Error('Otra ventana actualizó el seguimiento. No se sobrescribió. Exporta tus cambios de esta sesión y vuelve a abrir para recuperar la versión más reciente.');
 const raw=JSON.stringify(state);localStorage.setItem(key,raw);baseline=raw;warning='';return true;
 }catch(e){warning=e.message+' Tus cambios de esta sesión pueden exportarse a JSON.';return false;}}
function backupBeforeImport(s){try{if(blocked||localStorage.getItem(key)!==baseline)throw Error();localStorage.setItem(key+'-before-import',JSON.stringify(s));return true;}catch{return false;}}
window.SentinelStorage={load,save,warning:()=>warning,backupBeforeImport,previousImport:()=>{const s=localStorage.getItem(key+'-before-import');return s?SentinelModel.validate(JSON.parse(s)):null;},rejectedRecovery:()=>localStorage.getItem(key+'-rejected-recovery')};
})();
