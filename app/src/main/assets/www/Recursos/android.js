/* Android v3.6: un solo Guardar y enviar (PDF), historial editable de 24 horas. */
'use strict';
(function(){
 const phone=typeof window.ConduceAndroid!=='undefined';
 const show=mode=>{
  document.body.classList.toggle('mobile-preview',mode==='preview');
  document.body.classList.toggle('mobile-capture',mode!=='preview');
  document.getElementById('mobileCapture')?.classList.toggle('selected',mode!=='preview');
  document.getElementById('mobilePreview')?.classList.toggle('selected',mode==='preview');
  setTimeout(()=>{window.dispatchEvent(new Event('resize'));if(mode==='preview')document.getElementById('previewViewport')?.scrollTo(0,0);},0);
 };
 document.getElementById('mobileCapture')?.addEventListener('click',()=>show('capture'));
 document.getElementById('mobilePreview')?.addEventListener('click',()=>show('preview'));
 document.getElementById('mobileSave')?.addEventListener('click',()=>document.getElementById('savePrint').click());
 if(!phone)return;
 show('capture');document.title='Conduce Salida · Android';
 const android=window.ConduceAndroid;
 let restoreInProgress=false,clearInProgress=false,saveTimer=0,sending=false;
 const status=text=>{const el=document.getElementById('toast');if(el){el.textContent=text;el.classList.add('show');setTimeout(()=>el.classList.remove('show'),4700);}};
 window.conduceAvisoAndroid=status;
 const readSlot=tipo=>{try{const raw=android.leerTemporal(tipo);return raw?JSON.parse(raw):null;}catch(e){return null;}};
 const isMeaningful=d=>Boolean(d&&(d.localidad||d.tipo||(d.conceptos||[]).length||Object.entries(d).some(([k,v])=>!['fecha','hora','autFecha','entFecha'].includes(k)&&(Array.isArray(v)?v.some(x=>String(x).trim()):String(v||'').trim()))));
 const saveSlot=(tipo,d)=>{if(!isMeaningful(d))return false;try{return android.guardarTemporal(tipo,JSON.stringify(d))===true;}catch(e){return false;}};
 const cancelScheduled=()=>{if(saveTimer)clearTimeout(saveTimer);saveTimer=0;};
 function saveDraftNow(){cancelScheduled();if(restoreInProgress||clearInProgress)return;const d=window.FormularioSalida.getData();if(isMeaningful(d))saveSlot('borrador',d);else android.borrarTemporal('borrador');updateDraftButton();}
 function scheduleDraft(){if(restoreInProgress||clearInProgress)return;cancelScheduled();saveTimer=setTimeout(saveDraftNow,450);}
 window.conduceTemporalCambio=scheduleDraft;
 window.conduceGuardarTemporalAhora=saveDraftNow;
 const tempPanel=document.createElement('div');tempPanel.className='temp-recovery no-print';
 const historyButton=document.createElement('button');historyButton.type='button';historyButton.className='btn btn-outline-primary btn-sm';historyButton.textContent='▤ Conduces de las últimas 24 horas';
 const draftButton=document.createElement('button');draftButton.type='button';draftButton.className='btn btn-outline-primary btn-sm';draftButton.textContent='✎ Continuar borrador';
 const tempLabel=document.createElement('div');tempLabel.className='temp-recovery-info';
 tempPanel.append(historyButton,draftButton,tempLabel);
 document.querySelector('.editor-intro')?.after(tempPanel);
 function listHistory(){try{const data=JSON.parse(android.listarConduces()||'[]');return Array.isArray(data)?data:[];}catch(e){return [];}}
 function updateDraftButton(){const draft=readSlot('borrador');draftButton.hidden=!draft;}
 function updateHistoryCount(){const count=listHistory().length;tempLabel.textContent=count?`${count} conduce${count===1?'':'s'} disponible${count===1?'':'s'} para recuperar durante 24 horas.`:'No hay conduces guardados en las últimas 24 horas.';}
 function restore(d){const current=window.FormularioSalida.getData();if(isMeaningful(current)&&!window.confirm('Se reemplazarán los datos actuales por el conduce elegido. ¿Continuar?'))return false;
  cancelScheduled();restoreInProgress=true;try{window.FormularioSalida.setData(d);}finally{restoreInProgress=false;}
  saveDraftNow();show('capture');status('Conduce recuperado. Puedes editarlo y volver a Guardar y enviar.');return true;
 }
 draftButton.addEventListener('click',()=>{const obj=readSlot('borrador');if(!obj){updateDraftButton();status('El borrador ya no está disponible.');return;}restore(obj.data);});
 // La tabla muestra exactamente los cuatro datos solicitados. Cada fila es seleccionable.
 const overlay=document.createElement('div');overlay.className='history-overlay no-print';overlay.hidden=true;
 overlay.innerHTML=`<section class="history-dialog" role="dialog" aria-modal="true" aria-labelledby="historyTitle"><header><h2 id="historyTitle">Conduces de las últimas 24 horas</h2><button id="historyClose" type="button" class="btn btn-light" aria-label="Cerrar historial">×</button></header><p>Toca un conduce para cargarlo y editarlo. El original permanece en la lista hasta caducar.</p><div class="history-scroll"><table class="history-table"><thead><tr><th>Fecha</th><th>Hora</th><th>Localidad</th><th>Persona que retira</th></tr></thead><tbody id="historyRows"></tbody></table></div><p class="history-empty" id="historyEmpty" hidden>No hay conduces guardados durante las últimas 24 horas.</p><footer><button type="button" class="btn btn-outline-secondary" id="historyDismiss">Cerrar</button></footer></section>`;
 document.body.append(overlay);
 const closeHistory=()=>{overlay.hidden=true;};
 const dateLabel=v=>/^\d{4}-\d{2}-\d{2}$/.test(v||'')?v.slice(8,10)+'/'+v.slice(5,7)+'/'+v.slice(0,4):(v||'—');
 function renderHistory(){const rows=document.getElementById('historyRows');rows.replaceChildren();const results=listHistory();document.getElementById('historyEmpty').hidden=Boolean(results.length);
  for(const record of results){const tr=document.createElement('tr');tr.tabIndex=0;tr.setAttribute('role','button');tr.setAttribute('aria-label',`Recuperar conduce del ${record.fecha||'fecha sin especificar'} para ${record.persona||'persona no indicada'}`);
   const fields=[dateLabel(record.fecha),record.hora||'—',record.localidad||'—',record.persona||'—'];
   for(const label of fields){const td=document.createElement('td');td.textContent=label;tr.append(td);}
   const open=()=>{const raw=android.recuperarConduce(String(record.id));if(!raw){status('Ese conduce venció o no está disponible.');renderHistory();updateHistoryCount();return;}
      try{if(restore(JSON.parse(raw)))closeHistory();}catch(e){status('No se pudo recuperar el conduce.');}};
   tr.addEventListener('click',open);tr.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});rows.append(tr);
  }
 }
 historyButton.addEventListener('click',()=>{renderHistory();overlay.hidden=false;document.getElementById('historyClose').focus();});
 overlay.querySelector('#historyClose').addEventListener('click',closeHistory);
 overlay.querySelector('#historyDismiss').addEventListener('click',closeHistory);
 overlay.addEventListener('click',e=>{if(e.target===overlay)closeHistory();});
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!overlay.hidden){closeHistory();e.stopPropagation();}});
 window.conduceHistorialActualizado=()=>{updateHistoryCount();if(!overlay.hidden)renderHistory();};
 document.getElementById('reset')?.addEventListener('click',()=>{
  cancelScheduled();clearInProgress=true;const current=window.FormularioSalida.getData();if(isMeaningful(current))saveSlot('ultimo',current);
  android.borrarTemporal('borrador');setTimeout(()=>{clearInProgress=false;updateDraftButton();updateHistoryCount();},0);
 },true);
 document.addEventListener('visibilitychange',()=>{if(document.hidden)saveDraftNow();});window.addEventListener('pagehide',saveDraftNow);
 window.conduceVolverAndroid=()=>{if(!overlay.hidden){closeHistory();return true;}if(document.body.classList.contains('mobile-preview')){show('capture');return true;}return false;};
 updateDraftButton();updateHistoryCount();
 const previewButton=document.getElementById('savePrint');
 const mobileButton=document.getElementById('mobileSave');
 if(previewButton)previewButton.textContent='Guardar y enviar';
 if(mobileButton)mobileButton.textContent='Guardar y enviar';
 async function saveAndSend(){if(sending)return;const errors=window.FormularioSalida.checkFit();if(errors.length){status(errors[0]);return;}
  const d=window.FormularioSalida.getData();sending=true;previewButton.disabled=true;mobileButton.disabled=true;
  try {
   android.setAction('save_outlook');
   if(android.setPendingConduce(JSON.stringify(d))!==true)throw Error('No se pudieron preparar los datos para el historial.');
   await window.exportarConduce(d,'pdf');
   saveDraftNow();
   status('Generando PDF y preparando su envío a Outlook…');
  } catch(e){status('Error al preparar PDF: '+(e.message||String(e)));}
  finally{sending=false;previewButton.disabled=false;mobileButton.disabled=false;}
 }
 previewButton?.addEventListener('click',saveAndSend);
})();