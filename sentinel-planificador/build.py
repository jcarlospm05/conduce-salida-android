from pathlib import Path
import shutil
r=Path(__file__).parent
src=r/'src'
template=(src/'index.template.html').read_text()
css=(src/'styles.css').read_text()
scripts='\n'.join((src/n).read_text() for n in ['seed.js','model.js','storage.js','reports.js','app.js'])
assert '</script' not in scripts.lower()
html=template.replace('<!-- STYLES -->','<style>\n'+css+'\n</style>').replace('<!-- SCRIPTS -->','<script>\n'+scripts+'\n</script>')
(r/'SENTINEL-Planificador.html').write_text(html)
(r/'index.html').write_text(html)
modular=template.replace('<!-- STYLES -->','<link rel="stylesheet" href="styles.css">').replace('<!-- SCRIPTS -->','\n'.join(f'<script src="{s}"></script>' for s in ['seed.js','model.js','storage.js','reports.js','app.js']))
(src/'index.html').write_text(modular)
print('HTML portable y entrada modular generados.')
