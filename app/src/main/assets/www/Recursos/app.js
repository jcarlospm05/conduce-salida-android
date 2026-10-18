/* Formulario de salida v2.3 — datos locales, sin base de datos ni red. */
'use strict';
const LOCS=['TSB','TRH','OP','PTP','STI'];
const TIPOS=['Terceros','Interno'];
// Mantener la lógica de captura separada del documento que se imprime.
const THIRD_FIELDS=['empresa','rnc','chofer','cedulaChofer','cantidadTerceros','disposicionTerceros'];
const INTERNAL_FIELDS=['nombreInterno','posicionInterno','cantidadInterno','ubicacionInterno','disposicionInterno'];
function updateSectorAvailability(){
 const tipo=form.querySelector('[name="tipo"]:checked')?.value||'';
 for(const section of document.querySelectorAll('.sector-editor[data-sector]')){
  const active=section.dataset.sector===tipo;
  section.classList.toggle('sector-disabled',!active);
  section.setAttribute('aria-disabled',String(!active));
  for(const field of section.querySelectorAll('input,textarea,button,select'))field.disabled=!active;
  const status=section.querySelector('.sector-state');
  if(status)status.textContent=active?'Activo para completar':tipo?'Desactivado para esta salida':'Selecciona el tipo de salida';
 }
}
const CONCEPTOS=['Venta bienes','Servicio rescate','Despacho','Mantenimiento','Importance: High'];
const form=document.getElementById('dataForm');
const paper=document.getElementById('printPage');
const stage=document.getElementById('paperStage');
const viewport=document.getElementById('previewViewport');
const modal=document.getElementById('formatModal');
let saving=false,toastClock=0;
const items={terceros:'',internos:''};
const MAX_MATERIAL_LINES=8;
const normalizedMaterials=(input)=>Array.isArray(input)?input.map(x=>String(x||'').trim()).filter(Boolean).join(' - '):String(input||'').trim();
const splitMaterials=(input)=>String(input||'').split(/\s+-\s+|\n+/).map(x=>x.trim()).filter(Boolean);
function isoNow(){const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
function inputOptions(container,name,choices,multiple){container.replaceChildren();for(const choice of choices){const label=document.createElement('label');const input=document.createElement('input');input.type=multiple?'checkbox':'radio';input.name=name;input.value=choice;label.append(input,document.createTextNode(choice));container.append(label);}}
function emptyData(){const d={};for(const element of form.querySelectorAll('[name]')){if(element.type==='radio'||element.type==='checkbox')continue;d[element.name]=element.value.trim();}d.localidad=form.querySelector('[name="localidad"]:checked')?.value||'';d.tipo=form.querySelector('[name="tipo"]:checked')?.value||'';d.conceptos=Array.from(form.querySelectorAll('[name="conceptos"]:checked'),x=>x.value);d.materialesTerceros=splitMaterials(items.terceros);
 d.materialesInternos=splitMaterials(items.internos);
 // Nunca imprimir, exportar ni respaldar valores del sector no seleccionado.
 if(d.tipo!=='Terceros'){for(const key of THIRD_FIELDS)d[key]='';d.materialesTerceros=[];}
 if(d.tipo!=='Interno'){for(const key of INTERNAL_FIELDS)d[key]='';d.materialesInternos=[];}
 return d;}
function shortDate(v){if(!/^\d{4}-\d{2}-\d{2}$/.test(v||''))return v||'';const [y,m,d]=v.split('-').map(Number);return `${d}/${m}/${y}`;}
function longDate(v){if(!/^\d{4}-\d{2}-\d{2}$/.test(v||''))return v||'';const [y,m,d]=v.split('-').map(Number);return new Intl.DateTimeFormat('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'}).format(new Date(y,m-1,d,12));}
function printChoices(id,options,selected){const group=document.getElementById(id);group.replaceChildren();for(const name of options){const item=document.createElement('span');item.className='choice';const label=document.createElement('span');label.className='choice-label';label.textContent=name;const sq=document.createElement('span');sq.className='square'+(selected.includes(name)?' on':'');sq.textContent=selected.includes(name)?'X':'';item.append(label,sq);group.append(item);}}
function makeMatrix(containerId,materialList){const holder=document.getElementById(containerId);holder.textContent=normalizedMaterials(materialList);}
function materialLines(sector){
 const id=sector==='terceros'?'docTerceros':'docInternos';const el=document.getElementById(id);
 if(!el||!el.textContent.trim())return 0;
 const clone=el.cloneNode(true);clone.removeAttribute('id');
 clone.style.cssText='position:absolute;left:-9999px;top:0;width:'+el.clientWidth+'px;height:auto;min-height:0;max-height:none;overflow:visible;visibility:hidden';
 paper.append(clone);
 const cs=getComputedStyle(clone),line=parseFloat(cs.lineHeight)||15;
 const top=parseFloat(cs.paddingTop)||0,bottom=parseFloat(cs.paddingBottom)||0;
 const contentHeight=clone.scrollHeight-top-bottom;clone.remove();
 return Math.max(1,Math.ceil((contentHeight-.2)/line));
}
function renderMaterialEditor(sector){
 const holder=document.getElementById(sector==='terceros'?'itemsTerceros':'itemsInternos');holder.replaceChildren();
 const area=document.createElement('textarea');area.className='form-control material-textarea';area.rows=5;
 area.placeholder='Escriba aquí o agregue cada artículo. Se acomodarán automáticamente en renglones.';
 area.value=items[sector];area.setAttribute('aria-label',`Artículos y materiales de ${sector}`);
 area.addEventListener('input',()=>{items[sector]=area.value;refresh();});
 const pending=document.createElement('input');pending.type='text';pending.className='form-control new-material-input';
 pending.placeholder='Siguiente artículo o código';pending.setAttribute('aria-label',`Nuevo artículo de ${sector}`);
 pending.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();addMaterial(sector);}});
 holder.append(area,pending);
}
function addMaterial(sector){
 const active=form.querySelector('[name="tipo"]:checked')?.value;
 if(active!==(sector==='terceros'?'Terceros':'Interno'))return;
 const holder=document.getElementById(sector==='terceros'?'itemsTerceros':'itemsInternos');
 const pending=holder.querySelector('.new-material-input');const area=holder.querySelector('.material-textarea');
 const next=(pending?.value||'').trim();if(!next){pending?.focus();return;}
 const previous=items[sector];items[sector]=previous.trim()?previous.trim()+' - '+next:next;
 area.value=items[sector];refresh();
 if(checkFit().some(msg=>msg.startsWith('Materiales de '+(sector==='terceros'?'terceros':'personal interno')))){
   items[sector]=previous;area.value=previous;refresh();toast('No cabe este artículo en las ocho líneas del conduce.');return;
 }
 pending.value='';pending.focus();
}
function refresh(){updateSectorAvailability();const d=emptyData();for(const el of document.querySelectorAll('[data-field]')){const key=el.dataset.field;el.textContent=key==='fecha'||key==='entFecha'?longDate(d[key]):key==='autFecha'?shortDate(d[key]):key==='hora'?(d.hora||''):d[key]||'';}
 printChoices('viewLoc',LOCS,d.localidad?[d.localidad]:[]);printChoices('viewTipo',TIPOS,d.tipo?[d.tipo]:[]);printChoices('viewConcepto',CONCEPTOS,d.conceptos);
 makeMatrix('docTerceros',d.materialesTerceros);makeMatrix('docInternos',d.materialesInternos);
 for(const sector of ['terceros','internos']){
  const label=document.getElementById(sector==='terceros'?'countTerceros':'countInternos');
  label.textContent=`${materialLines(sector)} de ${MAX_MATERIAL_LINES} líneas`;
 }
 const errs=checkFit();document.getElementById('statusText').textContent=errs.length?'Revisar espacio del documento':'Listo para guardar e imprimir';document.getElementById('validationStatus').textContent=errs.length?errs[0]:'Una página carta · Texto automático hasta 8 líneas';
 window.conduceTemporalCambio?.();
}
function checkFit(){const errors=[];
 if(!form.querySelector('[name="tipo"]:checked'))errors.push('Selecciona primero el tipo de salida: Terceros o Interno.');
 for(const [id,sector] of [['docTerceros','terceros'],['docInternos','personal interno']]){
  const el=document.getElementById(id);
  if(el.textContent.trim()&&(materialLines(id==='docTerceros'?'terceros':'internos')>MAX_MATERIAL_LINES||el.scrollHeight>el.clientHeight+1))errors.push(`Materiales de ${sector}: se supera el espacio de 8 líneas. Revise los artículos.`);
 }
 for(const el of paper.querySelectorAll('.doc-value')){if(el.textContent&&el.scrollHeight>el.clientHeight+2){errors.push('Hay campos demasiado largos para una sola página carta.');break;}}
 const bounds=paper.querySelector('.main-doc-table').getBoundingClientRect();const sign=paper.querySelector('.signatures-document').getBoundingClientRect();if(bounds.bottom>sign.top-8)errors.push('Los datos invaden el espacio de firmas.');return errors;
}
function fitPage(){if(!viewport.clientWidth)return;const scale=Math.min(1,(viewport.clientWidth-45)/816);paper.style.transform=`scale(${scale})`;stage.style.width=`${816*scale}px`;stage.style.height=`${1056*scale}px`;document.getElementById('zoomLabel').textContent=`${Math.round(scale*100)}%`;}
function reset(){form.reset();for(const key of ['fecha','autFecha','entFecha'])form.elements.namedItem(key).value=isoNow();form.elements.namedItem('hora').value=new Date().toTimeString().slice(0,5);items.terceros='';items.internos='';renderMaterialEditor('terceros');renderMaterialEditor('internos');refresh();}
function setData(d){
 reset();
 // Respaldos anteriores a v3.5: recuperar el tipo si solo se llenó un sector.
 if(!d.tipo){
  const filled=keys=>keys.some(key=>String(d[key]||'').trim());
  const hasThird=filled(THIRD_FIELDS)||(d.materialesTerceros||[]).length>0;
  const hasInternal=filled(INTERNAL_FIELDS)||(d.materialesInternos||[]).length>0;
  if(hasThird!==hasInternal)d={...d,tipo:hasThird?'Terceros':'Interno'};
 }
 for(const [key,val] of Object.entries(d)){if(key==='materialesTerceros'){items.terceros=normalizedMaterials(val);renderMaterialEditor('terceros');continue;}if(key==='materialesInternos'){items.internos=normalizedMaterials(val);renderMaterialEditor('internos');continue;}if(key==='conceptos'){form.querySelectorAll('[name="conceptos"]').forEach(x=>x.checked=val.includes(x.value));continue;}if(['localidad','tipo'].includes(key)){const radio=Array.from(form.querySelectorAll(`[name="${key}"]`)).find(x=>x.value===val);if(radio)radio.checked=true;continue;}if(form.elements.namedItem(key))form.elements.namedItem(key).value=val;}refresh();}
function toast(text){const el=document.getElementById('toast');el.textContent=text;el.classList.add('show');clearTimeout(toastClock);toastClock=setTimeout(()=>el.classList.remove('show'),3700);}
function showModal(){const errors=checkFit();if(errors.length){toast(errors[0]);return;}modal.hidden=false;}
function hideModal(){modal.hidden=true;}
async function confirmExport(){if(saving)return;const errors=checkFit();if(errors.length){toast(errors[0]);hideModal();return;}const data=emptyData();const ext=document.querySelector('[name="format"]:checked').value;const button=document.getElementById('confirmSave');button.disabled=true;saving=true;try{await window.exportarConduce(data,ext);hideModal();if(window.ConduceAndroid){toast('Documento preparado. Selecciona correo u otra aplicación para enviarlo.');}else{toast('Archivo descargado. Seleccione su impresora.');setTimeout(()=>window.print(),1000);}}catch(err){console.error(err);toast(`No se pudo guardar: ${err.message||err}`);}finally{button.disabled=false;saving=false;}}
inputOptions(document.getElementById('loc-set'),'localidad',LOCS,false);inputOptions(document.getElementById('tipo-set'),'tipo',TIPOS,false);inputOptions(document.getElementById('concepto-set'),'conceptos',CONCEPTOS,true);
document.querySelectorAll('[data-add]').forEach(button=>button.addEventListener('click',()=>addMaterial(button.dataset.add)));
form.addEventListener('input',refresh);form.addEventListener('change',refresh);form.addEventListener('submit',e=>e.preventDefault());document.getElementById('reset').addEventListener('click',reset);if(!window.ConduceAndroid)document.getElementById('savePrint').addEventListener('click',showModal);document.getElementById('cancelModal')?.addEventListener('click',hideModal);document.getElementById('cancelX')?.addEventListener('click',hideModal);document.getElementById('confirmSave')?.addEventListener('click',confirmExport);modal?.addEventListener('click',e=>{if(e.target===modal)hideModal();});document.addEventListener('keydown',e=>{if(e.key==='Escape')hideModal();});window.addEventListener('resize',fitPage);reset();requestAnimationFrame(fitPage);
window.FormularioSalida={getData:emptyData,setData,checkFit,refresh};