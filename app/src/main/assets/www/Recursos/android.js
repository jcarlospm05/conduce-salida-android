/* Android: captura original, guardar en Descargas y compartir EXCLUSIVAMENTE en Outlook. */
'use strict';
(function(){
  const phone=typeof window.ConduceAndroid!=='undefined';
  const show=(mode)=>{
    document.body.classList.toggle('mobile-preview',mode==='preview');
    document.body.classList.toggle('mobile-capture',mode!=='preview');
    document.getElementById('mobileCapture')?.classList.toggle('selected',mode!=='preview');
    document.getElementById('mobilePreview')?.classList.toggle('selected',mode==='preview');
    setTimeout(()=>{window.dispatchEvent(new Event('resize'));if(mode==='preview')document.getElementById('previewViewport')?.scrollTo(0,0);},0);
  };
  document.getElementById('mobileCapture')?.addEventListener('click',()=>show('capture'));
  document.getElementById('mobilePreview')?.addEventListener('click',()=>show('preview'));
  document.getElementById('mobileSave')?.addEventListener('click',()=>document.getElementById('savePrint').click());
  window.conduceVolverAndroid=()=>{
    const modal=document.getElementById('formatModal');
    if(modal&&!modal.hidden){document.getElementById('cancelModal').click();return true;}
    if(document.body.classList.contains('mobile-preview')){show('capture');return true;}
    return false;
  };
  if(!phone)return;
  show('capture');
  document.title='Conduce Salida · Android';

  // Respaldo privado local; dos registros con vencimiento nativo a las 24 horas.
  let restoreInProgress=false,clearInProgress=false,saveTimer=0;
  const timeLabel=ts=>new Date(ts).toLocaleString('es-DO',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
  const readSlot=tipo=>{
    try {const raw=window.ConduceAndroid.leerTemporal(tipo);return raw?JSON.parse(raw):null;}
    catch(e){return null;}
  };
  const isMeaningful=d=>Boolean(
    d&&(d.localidad||d.tipo||(d.conceptos||[]).length||
    Object.entries(d).some(([k,v])=>!['fecha','hora','autFecha','entFecha'].includes(k)&&
      (Array.isArray(v)?v.some(x=>String(x).trim()):String(v||'').trim()))));
  const saveSlot=(tipo,d)=>{
    if(!isMeaningful(d))return false;
    try{return window.ConduceAndroid.guardarTemporal(tipo,JSON.stringify(d))===true;}
    catch(e){return false;}
  };
  const cancelScheduled=()=>{if(saveTimer)clearTimeout(saveTimer);saveTimer=0;};
  function saveDraftNow(){
    cancelScheduled();if(restoreInProgress||clearInProgress)return;
    const d=window.FormularioSalida.getData();
    if(isMeaningful(d))saveSlot('borrador',d);
    else window.ConduceAndroid.borrarTemporal('borrador');
    updateRecoveryButtons();
  }
  function scheduleDraft(){
    if(restoreInProgress||clearInProgress)return;
    cancelScheduled();saveTimer=setTimeout(saveDraftNow,450);
  }
  window.conduceTemporalCambio=scheduleDraft;
  window.conduceGuardarTemporalAhora=saveDraftNow;

  const tempPanel=document.createElement('div');tempPanel.className='temp-recovery no-print';
  const lastButton=document.createElement('button');lastButton.type='button';lastButton.className='btn btn-outline-primary btn-sm';lastButton.textContent='↶ Recuperar último conduce';
  const draftButton=document.createElement('button');draftButton.type='button';draftButton.className='btn btn-outline-primary btn-sm';draftButton.textContent='✎ Continuar borrador';
  const tempLabel=document.createElement('div');tempLabel.className='temp-recovery-info';
  tempPanel.append(lastButton,draftButton,tempLabel);
  document.querySelector('.editor-intro')?.after(tempPanel);
  function updateRecoveryButtons(){
    const last=readSlot('ultimo'),draft=readSlot('borrador');
    lastButton.hidden=!last;draftButton.hidden=!draft;
    if(last)tempLabel.textContent='Último conduce: '+timeLabel(last.savedAt)+' · disponible por 24 horas desde su guardado.';
    else if(draft)tempLabel.textContent='Tienes un borrador temporal del '+timeLabel(draft.savedAt)+'.';
    else tempLabel.textContent='Los conduces se conservan temporalmente durante 24 horas en este celular.';
  }
  function restoreSlot(tipo){
    const item=readSlot(tipo);if(!item){status('Ya no hay un respaldo válido en las últimas 24 horas.');updateRecoveryButtons();return;}
    const current=window.FormularioSalida.getData();
    if(isMeaningful(current)&&!window.confirm('Se reemplazarán los datos actuales por el conduce guardado. ¿Continuar?'))return;
    cancelScheduled();restoreInProgress=true;
    try {window.FormularioSalida.setData(item.data);}
    finally {restoreInProgress=false;}
    saveDraftNow();show('capture');status('Conduce recuperado. Puedes modificarlo y volver a guardar o enviar el PDF.');
  }
  lastButton.addEventListener('click',()=>restoreSlot('ultimo'));
  draftButton.addEventListener('click',()=>restoreSlot('borrador'));
  document.getElementById('reset')?.addEventListener('click',()=>{
    cancelScheduled();clearInProgress=true;
    const active=window.FormularioSalida.getData();
    if(isMeaningful(active))saveSlot('ultimo',active);
    window.ConduceAndroid.borrarTemporal('borrador');
    setTimeout(()=>{clearInProgress=false;updateRecoveryButtons();},0);
  },true);
  document.addEventListener('visibilitychange',()=>{if(document.hidden)saveDraftNow();});
  window.addEventListener('pagehide',saveDraftNow);
  updateRecoveryButtons();

  const previewButton=document.getElementById('savePrint');
  if(previewButton)previewButton.textContent='Guardar o enviar por Outlook';
  const mobileButton=document.getElementById('mobileSave');
  if(mobileButton)mobileButton.textContent='Guardar / Outlook';
  document.getElementById('modalTitle').textContent='Guardar o enviar documento';
  const hint=document.querySelector('.modal-hint');
  if(hint)hint.textContent='Guardar: Descargas/Conduce Salida (Android 10+). Enviar: abre únicamente Microsoft Outlook con el archivo adjunto.';
  const accept=document.getElementById('confirmSave');
  accept.style.display='none';
  const row=document.createElement('div');row.className='android-choices';
  const download=document.createElement('button');download.type='button';download.className='btn btn-primary';download.textContent='↓ Guardar en Descargas';
  const outlook=document.createElement('button');outlook.type='button';outlook.className='btn btn-outlook';outlook.textContent='✉ Enviar por Outlook';
  row.append(download,outlook);
  document.querySelector('.modal-actions').after(row);
  let sending=false;
  const status=(text)=>{const el=document.getElementById('toast');if(el){el.textContent=text;el.classList.add('show');setTimeout(()=>el.classList.remove('show'),4000);}};
  window.conduceAvisoAndroid=status;
  async function run(action){
    if(sending)return;
    const errors=window.FormularioSalida?.checkFit?.()||[];
    if(errors.length){status(errors[0]);return;}
    const format=document.querySelector('[name="format"]:checked')?.value||'pdf';
    sending=true;download.disabled=true;outlook.disabled=true;
    try{
      window.ConduceAndroid.setAction(action);
      const current=window.FormularioSalida.getData();
      await window.exportarConduce(current,format);
      saveSlot('ultimo',current);
      saveDraftNow();updateRecoveryButtons();
      document.getElementById('formatModal').hidden=true;
      if(action==='outlook')status('Preparando el adjunto para Outlook…');
      else status('Guardando el documento en Descargas…');
    }catch(error){status('Error al generar documento: '+(error.message||String(error)));}
    finally{sending=false;download.disabled=false;outlook.disabled=false;}
  }
  download.addEventListener('click',()=>run('download'));
  outlook.addEventListener('click',()=>run('outlook'));
})();