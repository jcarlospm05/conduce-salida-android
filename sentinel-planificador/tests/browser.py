from pathlib import Path
from playwright.sync_api import sync_playwright
import json,tempfile,os
r=Path(__file__).resolve().parents[1]
results=[]
def ok(name):results.append(name);print('PASS',name)
with sync_playwright() as p:
 browser_path=os.environ.get('SENTINEL_CHROMIUM_PATH')
 b=p.chromium.launch(**({'executable_path':browser_path} if browser_path else {}),headless=True,args=['--no-sandbox'])
 page=b.new_page(viewport={'width':1440,'height':1000},accept_downloads=True)
 errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto((r/'SENTINEL-Planificador.html').as_uri())
 page.wait_for_selector('.task')
 assert page.locator('.task').count()==56
 ok('HTML portable abre sin servidor y muestra 56 tareas')
 page.screenshot(path=str(r/'vista-tablero.png'),full_page=True)
 page.locator('#search').fill('Hourly')
 assert page.locator('.task').count()>0 and page.locator('.task').count()<56
 page.locator('#clearFilters').click()
 ok('Búsqueda y filtros')
 page.locator('#newTask').click()
 page.locator('#fTitle').fill('Prueba de seguimiento <img src=x onerror=alert(1)>')
 page.locator('#fDetail').fill('Tarea agregada por el propietario')
 page.locator('#fNotes').fill('Mi nota de prueba')
 page.locator('#taskForm button[type=submit]').click()
 assert page.locator('.task').count()==57
 assert page.locator('.task img').count()==0
 ok('Crear tarea y mostrar texto sin ejecutar HTML')
 page.reload()
 assert page.locator('.task').count()==57
 ok('Persistencia local al reabrir')
 page.locator('[data-edit=P01]').first.click()
 page.locator('#fStatus').select_option('Completada')
 page.locator('#taskForm button[type=submit]').click()
 assert 'evidencia' in page.locator('#formError').inner_text()
 page.locator('#fEvidence').fill('Decisiones revisadas con propietario')
 page.locator('#taskForm button[type=submit]').click()
 assert page.locator('[data-edit=P01]').first.locator('xpath=ancestor::article').inner_text().find('Completada')>=0
 ok('Completar exige evidencia, registra estado')
 page.locator('[data-edit=D01]').first.click()
 page.locator('#fStatus').select_option('Completada')
 page.locator('#fEvidence').fill('Intento con dependencia pendiente')
 page.locator('#taskForm button[type=submit]').click()
 assert 'dependencias' in page.locator('#formError').inner_text()
 page.once('dialog',lambda d:d.accept())
 page.locator('#cancelDialog').click()
 ok('Dependencias bloquean cierre sin completar')
 with page.expect_download() as d:page.locator('#exportJson').click()
 export=Path(tempfile.gettempdir())/'sentinel-test-export.json';d.value.save_as(str(export))
 snapshot=json.loads(export.read_text());assert len(snapshot['tasks'])==57
 with page.expect_download() as d:page.locator('#exportContext').click()
 txt=Path(tempfile.gettempdir())/'sentinel-test-context.txt';d.value.save_as(str(txt))
 assert 'DECISIONES VIGENTES' in txt.read_text() and 'Mi nota de prueba' in txt.read_text()
 ok('Exportar JSON y contexto TXT completos')
 page.locator('#importFile').set_input_files({'name':'bad.json','mimeType':'application/json','buffer':b'{"schemaVersion":99}'})
 assert page.locator('.task').count()==57
 ok('Importación inválida no cambia datos')
 page.once('dialog',lambda d:d.accept())
 with page.expect_download():page.locator('#importFile').set_input_files(str(export))
 page.wait_for_function("JSON.parse(localStorage.getItem('sentinel-project-tracker-v1')).activity[0].text.includes('Importado')")
 ok('Importación válida preserva copia anterior e importa')
 page.locator('[data-view=agents]').click();assert page.locator('#agents .panel').count()==3
 page.locator('[data-agenttasks=a2]').click();assert 'Arquitectura' in page.locator('#agentFilter option:checked').inner_text()
 ok('Tres agentes e instrucciones por tarea')
 page.locator('#clearFilters').click()
 page.set_viewport_size({'width':390,'height':844})
 assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
 page.screenshot(path=str(r/'vista-movil.png'),full_page=True)
 ok('Vista móvil sin desbordamiento horizontal')
 page2=b.new_page();page2.goto((r/'src/index.html').as_uri());page2.wait_for_selector('.task');assert page2.locator('.task').count()==56
 ok('Versión modular abre sin dependencias externas')
 assert not errors,errors
 ok('Sin errores JavaScript en recorrido probado')
 b.close()
(r/'RESULTADO_PRUEBAS.json').write_text(json.dumps({'browser':'Chromium headless (Playwright)' ,'passed':results,'limits':['No prueba la futura app Access ni SharePoint.','No valida publicación web; archivo probado localmente.']},ensure_ascii=False,indent=2))
