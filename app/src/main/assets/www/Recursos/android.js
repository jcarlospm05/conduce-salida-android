/* Adaptación del interfaz al celular; el documento original HTML no se modifica. */
'use strict';
(function(){
  const phone = typeof window.ConduceAndroid !== 'undefined';
  const show = (mode) => {
    document.body.classList.toggle('mobile-preview',mode==='preview');
    document.body.classList.toggle('mobile-capture',mode!=='preview');
    const capture=document.getElementById('mobileCapture');
    const preview=document.getElementById('mobilePreview');
    capture?.classList.toggle('selected',mode!=='preview');
    preview?.classList.toggle('selected',mode==='preview');
    setTimeout(()=>{
      const ev=new Event('resize');window.dispatchEvent(ev);
      if(mode==='preview')document.getElementById('previewViewport')?.scrollTo(0,0);
    },0);
  };
  document.getElementById('mobileCapture')?.addEventListener('click',()=>show('capture'));
  document.getElementById('mobilePreview')?.addEventListener('click',()=>show('preview'));
  document.getElementById('mobileSave')?.addEventListener('click',()=>document.getElementById('savePrint').click());
  window.conduceVolverAndroid=()=>{
    if(!document.getElementById('formatModal').hidden){document.getElementById('cancelModal').click();return true;}
    if(document.body.classList.contains('mobile-preview')){show('capture');return true;}
    return false;
  };
  if(phone){
    show('capture');
    document.title='Conduce Salida · Android';
    const btn=document.getElementById('savePrint');
    if(btn)btn.innerHTML='▣ Guardar y compartir';
    const hint=document.querySelector('.modal-hint');
    if(hint)hint.textContent='Selecciona PDF para enviarlo por correo a la computadora. Word y Excel también se pueden compartir como archivos editables.';
  }
})();
