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
      await window.exportarConduce(window.FormularioSalida.getData(),format);
      document.getElementById('formatModal').hidden=true;
      if(action==='outlook')status('Preparando el adjunto para Outlook…');
      else status('Guardando el documento en Descargas…');
    }catch(error){status('Error al generar documento: '+(error.message||String(error)));}
    finally{sending=false;download.disabled=false;outlook.disabled=false;}
  }
  download.addEventListener('click',()=>run('download'));
  outlook.addEventListener('click',()=>run('outlook'));
})();