/* Exportadores sin servidor: Word y Excel nativos/editables; PDF vectorial; requiere JSZip local. */
'use strict';
(function(){
const xml=(v)=>String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;');
const bytes=(s)=>Uint8Array.from(atob(s),x=>x.charCodeAt(0));
const basename=(d)=>'Conduce_Salida_'+(d.fecha||'SinFecha').replace(/-/g,'');
async function descargar(blob,filename){
  if(window.ConduceAndroid && typeof window.ConduceAndroid.startShare==='function'){
    const base64=await new Promise((resolve,reject)=>{
      const reader=new FileReader();
      reader.onload=()=>{const uri=String(reader.result||'');const comma=uri.indexOf(',');if(comma<0)reject(new Error('No se pudo preparar el archivo'));else resolve(uri.slice(comma+1));};
      reader.onerror=()=>reject(new Error('No se pudo leer el documento generado.'));
      reader.readAsDataURL(blob);
    });
    // Send 48 KB base64 chunks across the JS bridge to avoid Android IPC limits.
    window.ConduceAndroid.startShare(filename,blob.type||'application/octet-stream');
    for(let i=0;i<base64.length;i+=49152){window.ConduceAndroid.appendChunk(base64.slice(i,i+49152));}
    window.ConduceAndroid.finishShare();
    return;
  }
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;a.download=filename;
  document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),15000);
}
const S=(value)=>value==null?'':String(value);
const sdate=(v)=>{if(!/^\d{4}-\d\d-\d\d$/.test(v||''))return S(v);const [y,m,d]=v.split('-').map(Number);return `${d}/${m}/${y}`;};
const ldate=(v)=>{if(!/^\d{4}-\d\d-\d\d$/.test(v||''))return S(v);const [y,m,d]=v.split('-').map(Number);return new Intl.DateTimeFormat('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'}).format(new Date(y,m-1,d,12));};
function wordPara(value='',opts={}){const content=xml(value).replace(/\r?\n/g,'</w:t><w:br/><w:t xml:space="preserve">');const pt=opts.size||8.4;const sz=Math.round(pt*2);return `<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="${opts.line||200}" w:lineRule="auto"/><w:jc w:val="${opts.align||'left'}"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>${opts.bold?'<w:b/>':''}<w:sz w:val="${sz}"/><w:color w:val="${opts.color||'101010'}"/></w:rPr><w:t xml:space="preserve">${content}</w:t></w:r></w:p>`;}
function wordCell(content,width,opts={}){const paragraphs=opts.nested?content:wordPara(content,{size:opts.size||8,bold:opts.bold,align:opts.align,line:opts.line||195});return `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/>${opts.gridspan?`<w:gridSpan w:val="${opts.gridspan}"/>`:''}<w:vAlign w:val="${opts.valign||'center'}"/>${opts.underline?'<w:tcBorders><w:bottom w:val="single" w:sz="5"/></w:tcBorders>':''}${opts.leftBorder?'<w:tcBorders><w:left w:val="single" w:sz="6"/></w:tcBorders>':''}<w:tcMar><w:top w:w="35" w:type="dxa"/><w:bottom w:w="25" w:type="dxa"/><w:left w:w="50" w:type="dxa"/><w:right w:w="50" w:type="dxa"/></w:tcMar></w:tcPr>${paragraphs}</w:tc>`;}
function wordRow(cells,height=0){return `<w:tr><w:trPr><w:cantSplit/>${height?`<w:trHeight w:val="${height}" w:hRule="atLeast"/>`:''}</w:trPr>${cells.join('')}</w:tr>`;}
const wordBorder=(type)=>type==='outer'?'<w:tblBorders><w:top w:val="single" w:sz="6"/><w:bottom w:val="single" w:sz="6"/><w:left w:val="single" w:sz="6"/><w:right w:val="single" w:sz="6"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>':type===false?'<w:tblBorders><w:top w:val="nil"/><w:bottom w:val="nil"/><w:left w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>':'<w:tblBorders><w:top w:val="single" w:sz="6"/><w:bottom w:val="single" w:sz="6"/><w:left w:val="single" w:sz="6"/><w:right w:val="single" w:sz="6"/><w:insideH w:val="single" w:sz="5"/><w:insideV w:val="single" w:sz="5"/></w:tblBorders>';
function wordTable(widths,rows,opts={}){return `<w:tbl><w:tblPr><w:tblW w:w="${widths.reduce((a,b)=>a+b,0)}" w:type="dxa"/><w:tblLayout w:type="fixed"/>${wordBorder(opts.borders)}<w:tblCellSpacing w:w="0" w:type="dxa"/></w:tblPr><w:tblGrid>${widths.map(w=>`<w:gridCol w:w="${w}"/>`).join('')}</w:tblGrid>${rows.join('')}</w:tbl>`;}
const wgap=(h)=>`<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="${h}" w:lineRule="exact"/></w:pPr><w:r><w:t> </w:t></w:r></w:p>`;
function wordMatrix(items,w){return wordPara((items||[]).join(' - '),{size:7.7,line:185});}
function wordSector(d,internal,w){const leftW=2010,rightW=w-leftW;const label=(k,v,h=330)=>wordRow([wordCell(k,leftW,{size:7.6,bold:true}),wordCell(v,rightW,{size:8.3,align:'center'})],h);const rows=[wordRow([wordCell(internal?'En caso personal interno':'En caso de terceros',w,{gridspan:2,align:'center',size:8.7,bold:true})],300)];
if(internal){rows.push(label('Nombre y Apellidos:',d.nombreInterno),label('Posición:',d.posicionInterno));rows.push(wordRow([wordCell('Herramientas, materiales o bienes:',leftW,{size:7.6,bold:true}),wordCell(wordMatrix(d.materialesInternos||[],rightW),rightW,{nested:true})],1450));rows.push(label('Cantidad:',d.cantidadInterno));rows.push(label('Breve descripción disposición final herramientas, materiales o bienes:',d.disposicionInterno,510));rows.push(label('Ubicación en caso de servicio de rescate:',d.ubicacionInterno,460));}
else{rows.push(label('Empresa:',d.empresa),label('RNC:',d.rnc),label('Nombre y Apellidos chofer:',d.chofer,460),label('Cédula chofer:',d.cedulaChofer));rows.push(wordRow([wordCell('Herramientas, materiales o bienes:',leftW,{size:7.6,bold:true}),wordCell(wordMatrix(d.materialesTerceros||[],rightW),rightW,{nested:true})],1450));rows.push(label('Cantidad:',d.cantidadTerceros));rows.push(label('Breve descripción disposición final herramientas, materiales o bienes:',d.disposicionTerceros,650));}
return wordTable([leftW,rightW],rows);}
function wordSign(d,internal,w){const L=internal?2200:1540;const R=w-L;const fields=internal?[['Nombre:',d.entNombre],['Firma:',d.entFirma],['Posición:',d.entPosicion],['Placa vehículo o ficha equipo:',d.entPlaca],['Fecha:',ldate(d.entFecha)]]:[['Nombre:',d.autNombre],['Firma:',d.autFirma],['Posición:',d.autPosicion],['Fecha:',sdate(d.autFecha)]];let rows=[wordRow([wordCell(internal?'Entregado a:':'Autorizado por:',w,{gridspan:2,bold:true,align:'center',size:8.4})],300)];for(const [label,value] of fields)rows.push(wordRow([wordCell(label,L,{size:7.8,bold:true}),wordCell(value,R,{size:8.8,align:'center'})],310));return wordTable([L,R],rows,{borders:false});}
function wordLogo(){return `<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0"/></w:pPr><w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0"><wp:extent cx="1260000" cy="490000"/><wp:docPr id="1" name="Logo Seaboard Marine"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="2" name="Logo"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1260000" cy="490000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>`;}
function wordDoc(d){const WIDTH=10920,HALF=5460;const mark=(ok)=>ok?'■':'□';const opts=(choices,value)=>choices.map(s=>`${s} ${mark(value.includes(s))}`).join('     ');
const optsTab=wordTable([1400,9520],[wordRow([wordCell('Localidad:',1400,{bold:true,size:8}),wordCell(opts(['TSB','TRH','OP','PTP','STI'],[d.localidad]),9520,{size:8.1})],280),wordRow([wordCell('Tipo salida:',1400,{bold:true}),wordCell(opts(['Terceros','Interno'],[d.tipo]),9520,{size:8.1})],280),wordRow([wordCell('Concepto salida:',1400,{bold:true}),wordCell(opts(['Venta bienes','Servicio rescate','Despacho','Mantenimiento','Importance: High'],d.conceptos||[]),9520,{size:7.4})],310)]);
// Side-by-side native Word table: no embedded page screenshot and no stacked nested halves.
const cols=[2010,3450,2010,3450];
const dual=(a,b,c,e,h=340)=>wordRow([wordCell(a,cols[0],{size:7.7,bold:true}),wordCell(b,cols[1],{size:8.3,align:'center'}),wordCell(c,cols[2],{size:7.7,bold:true}),wordCell(e,cols[3],{size:8.3,align:'center'})],h);
const details=wordTable(cols,[
 wordRow([wordCell('DATOS SOLICITUD SALIDA',WIDTH,{gridspan:4,bold:true,align:'center',size:9.2})],300),
 wordRow([wordCell('En caso de terceros',HALF,{gridspan:2,bold:true,align:'center'}),wordCell('En caso personal interno',HALF,{gridspan:2,bold:true,align:'center'})],300),
 dual('Empresa:',d.empresa,'Nombre y Apellidos:',d.nombreInterno),
 dual('RNC:',d.rnc,'Posición:',d.posicionInterno),
 dual('Nombre y Apellidos chofer:',d.chofer,'','',420),
 dual('Cédula chofer:',d.cedulaChofer,'',''),
 wordRow([wordCell('Herramientas, materiales o bienes:',cols[0],{size:7.6,bold:true}),wordCell(wordMatrix(d.materialesTerceros||[],cols[1]),cols[1],{nested:true}),wordCell('Herramientas, materiales o bienes:',cols[2],{size:7.6,bold:true}),wordCell(wordMatrix(d.materialesInternos||[],cols[3]),cols[3],{nested:true})],1450),
 dual('Cantidad:',d.cantidadTerceros,'Cantidad:',d.cantidadInterno),
 dual('Breve descripción disposición final herramientas, materiales o bienes:',d.disposicionTerceros,'Breve descripción disposición final herramientas, materiales o bienes:',d.disposicionInterno,640),
 dual('','', 'Ubicación en caso de servicio de rescate:',d.ubicacionInterno,420)
]);
const signCols=[1380,4080,1820,3640];
const signLine=(al,av,bl,bv)=>wordRow([
 wordCell(al,signCols[0],{size:7.7,bold:!!al}),wordCell(av,signCols[1],{size:8.3,align:'center',underline:true}),
 wordCell(bl,signCols[2],{size:7.7,bold:!!bl,leftBorder:true}),wordCell(bv,signCols[3],{size:8.3,align:'center',underline:true})],310);
const signs=wordTable(signCols,[
 wordRow([wordCell('Autorizado por:',5460,{gridspan:2,bold:true,align:'center',size:9}),wordCell('Entregado a:',5460,{gridspan:2,bold:true,align:'center',size:9,leftBorder:true})],320),
 signLine('Nombre:',d.autNombre,'Nombre:',d.entNombre),
 signLine('Firma:',d.autFirma,'Firma:',d.entFirma),
 signLine('Posición:',d.autPosicion,'Posición:',d.entPosicion),
 signLine('Fecha:',sdate(d.autFecha),'Placa vehículo o ficha equipo:',d.entPlaca),
 signLine('','', 'Fecha:',ldate(d.entFecha))
],{borders:'outer'});
const segments=[wordLogo(),wordPara('CONDUCE SALIDA HERRAMIENTAS, MATERIALES Y OTROS BIENES',{size:10.2,bold:true,align:'center'}),wgap(160),wordPara('Fecha:   '+ldate(d.fecha),{size:8,align:'right',bold:false}),wordPara('Hora:   '+S(d.hora),{size:8,align:'right'}),wgap(260),optsTab,wgap(290),details,wgap(540),signs,wgap(490),wordPara('Nota: En caso de que estos artículos no sean utilizados, según concepto salida, deberán ser retornados en su totalidad a la persona quien autorizó la salida.',{size:7.6})];
return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>${segments.join('')}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="410" w:right="660" w:bottom="750" w:left="660"/><w:pgBorders w:offsetFrom="page"><w:top w:val="single" w:sz="8" w:space="16"/><w:left w:val="single" w:sz="8" w:space="16"/><w:bottom w:val="single" w:sz="8" w:space="39"/><w:right w:val="single" w:sz="8" w:space="16"/></w:pgBorders></w:sectPr></w:body></w:document>`;}
async function createWord(d){const z=new JSZip();z.file('[Content_Types].xml','<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>');z.file('_rels/.rels','<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');z.file('word/_rels/document.xml.rels','<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo.png"/></Relationships>');z.file('word/document.xml',wordDoc(d));z.file('word/styles.xml','<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/></w:rPr><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:style></w:styles>');z.file('word/media/logo.png',bytes(LOGO_PNG_BASE64));return z.generateAsync({type:'blob',compression:'DEFLATE'});}
// Cada bloque de materiales usa una celda combinada editable con ajuste de texto.
const cellRef=(c,r)=>{let s='';while(c){c--;s=String.fromCharCode(65+c%26)+s;c=Math.floor(c/26);}return s+r;};
function createExcelXML(d){const cells=new Map(),merges=[],heights=new Map();const col=(n)=>n;
const place=(r,c,text,style=0)=>cells.set(cellRef(c,r),{r,c,t:S(text),style});const merge=(r1,c1,r2,c2)=>{if(r1!==r2||c1!==c2)merges.push(`${cellRef(c1,r1)}:${cellRef(c2,r2)}`);};
const block=(r,c1,c2,value,style=1)=>{merge(r,c1,r,c2);place(r,c1,value,style);};
const mergeBlock=(r1,c1,r2,c2,value,style=1)=>{merge(r1,c1,r2,c2);place(r1,c1,value,style);};
const rowHeight=(r,h)=>heights.set(r,h);
mergeBlock(1,1,3,26,'',0);rowHeight(1,22);rowHeight(2,24);rowHeight(3,17);
block(4,1,26,'CONDUCE SALIDA HERRAMIENTAS, MATERIALES Y OTROS BIENES',2);rowHeight(4,24);
block(5,21,23,'Fecha:',3);block(5,24,26,ldate(d.fecha),4);block(6,21,23,'Hora:',3);block(6,24,26,d.hora,4);
const mark=(active)=>active?'■':'□';
block(8,1,4,'Localidad:',3);block(8,5,26,['TSB','TRH','OP','PTP','STI'].map(x=>`${x} ${mark(d.localidad===x)}`).join('       '),5);
block(9,1,4,'Tipo salida:',3);block(9,5,26,['Terceros','Interno'].map(x=>`${x} ${mark(d.tipo===x)}`).join('          '),5);
block(10,1,4,'Concepto salida:',3);block(10,5,26,['Venta bienes','Servicio rescate','Despacho','Mantenimiento','Importance: High'].map(x=>`${x} ${mark((d.conceptos||[]).includes(x))}`).join('    '),6);rowHeight(10,26);
block(12,1,26,'DATOS SOLICITUD SALIDA',2);
block(13,1,13,'En caso de terceros',2);block(13,14,26,'En caso personal interno',2);
const fieldLeft=(r,k,v)=>{block(r,1,5,k,3);block(r,6,13,v,4);};const fieldRight=(r,k,v)=>{block(r,14,18,k,3);block(r,19,26,v,4);};
fieldLeft(14,'Empresa:',d.empresa);fieldRight(14,'Nombre y Apellidos:',d.nombreInterno);
fieldLeft(15,'RNC:',d.rnc);fieldRight(15,'Posición:',d.posicionInterno);
fieldLeft(16,'Nombre y Apellidos chofer:',d.chofer);fieldLeft(17,'Cédula chofer:',d.cedulaChofer);
mergeBlock(16,14,22,18,'Herramientas, materiales o bienes:',7);mergeBlock(18,1,24,5,'Herramientas, materiales o bienes:',7);
// Cada lado tiene una sola celda editable con ajuste automático de línea.
mergeBlock(18,6,24,13,(d.materialesTerceros||[]).join(' - '),9);
mergeBlock(16,19,22,26,(d.materialesInternos||[]).join(' - '),9);
fieldRight(23,'Cantidad:',d.cantidadInterno);mergeBlock(24,14,26,18,'Breve descripción disposición final herramientas, materiales o bienes:',7);mergeBlock(24,19,26,26,d.disposicionInterno,4);
fieldLeft(25,'Cantidad:',d.cantidadTerceros);mergeBlock(26,1,28,5,'Breve descripción disposición final herramientas, materiales o bienes:',7);mergeBlock(26,6,28,13,d.disposicionTerceros,4);
mergeBlock(27,14,28,18,'Ubicación en caso de servicio de rescate:',7);mergeBlock(27,19,28,26,d.ubicacionInterno,4);
for(let r=14;r<=28;r++)rowHeight(r,20);
block(30,1,13,'Autorizado por:',2);block(30,14,26,'Entregado a:',2);
const pair=(r,a,b,c,dv)=>{block(r,1,5,a,3);block(r,6,13,b,4);block(r,14,18,c,3);block(r,19,26,dv,4);};
pair(31,'Nombre:',d.autNombre,'Nombre:',d.entNombre);pair(32,'Firma:',d.autFirma,'Firma:',d.entFirma);pair(33,'Posición:',d.autPosicion,'Posición:',d.entPosicion);pair(34,'Fecha:',sdate(d.autFecha),'Placa vehículo o ficha equipo:',d.entPlaca);block(35,14,18,'Fecha:',3);block(35,19,26,ldate(d.entFecha),4);
for(let r=31;r<=35;r++)rowHeight(r,24);
block(37,1,26,'Nota: En caso de que estos artículos no sean utilizados, según concepto salida, deberán ser retornados en su totalidad a la persona quien autorizó la salida.',9);rowHeight(37,33);
const rows=new Map();for(const cell of cells.values()){if(!rows.has(cell.r))rows.set(cell.r,[]);rows.get(cell.r).push(cell);}
let xmlRows='';for(let r=1;r<=38;r++){const rs=(rows.get(r)||[]).sort((a,b)=>a.c-b.c);xmlRows+=`<row r="${r}"${heights.has(r)?` ht="${heights.get(r)}" customHeight="1"`:''}>`;for(const c of rs)xmlRows+=`<c r="${cellRef(c.c,r)}" s="${c.style}" t="inlineStr"><is><t xml:space="preserve">${xml(c.t)}</t></is></c>`;xmlRows+='</row>';}
const v=`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:Z38"/><sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews><sheetFormatPr defaultRowHeight="18"/><cols>${Array.from({length:26},(_,i)=>`<col min="${i+1}" max="${i+1}" width="6.2" customWidth="1"/>`).join('')}</cols><sheetData>${xmlRows}</sheetData><mergeCells count="${merges.length}">${merges.map(x=>`<mergeCell ref="${x}"/>`).join('')}</mergeCells><drawing r:id="rId1"/><printOptions horizontalCentered="1"/><pageMargins left="0.35" right="0.35" top="0.35" bottom="0.55" header="0" footer="0"/><pageSetup paperSize="1" orientation="portrait" fitToWidth="1" fitToHeight="1"/></worksheet>`;
return v;}
function excelStyles(){return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="4"><font><sz val="9"/><name val="Arial"/></font><font><b/><sz val="9"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font><font><sz val="8"/><name val="Arial"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color indexed="64"/></left><right style="thin"><color indexed="64"/></right><top style="thin"><color indexed="64"/></top><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="10"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf><xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf><xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center"/></xf><xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>`;}
async function createExcel(d){const z=new JSZip();z.file('[Content_Types].xml','<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>');z.file('_rels/.rels','<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');z.file('xl/workbook.xml','<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets><sheet name="Conduce salida" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm.Print_Area" localSheetId="0">\'Conduce salida\'!$A$1:$Z$38</definedName></definedNames></workbook>');z.file('xl/_rels/workbook.xml.rels','<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');z.file('xl/worksheets/sheet1.xml',createExcelXML(d));z.file('xl/styles.xml',excelStyles());z.file('xl/worksheets/_rels/sheet1.xml.rels','<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>');
// Solo el logo es una imagen; las áreas de materiales siguen siendo celdas editables.
const drawing=`<?xml version="1.0" encoding="UTF-8"?><xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><xdr:oneCellAnchor><xdr:from><xdr:col>11</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="1300000" cy="580000"/><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="1" name="Logo SEABOARD"/><xdr:cNvPicPr/></xdr:nvPicPr><xdr:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>`;
z.file('xl/drawings/drawing1.xml',drawing);z.file('xl/drawings/_rels/drawing1.xml.rels','<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/logo.png"/></Relationships>');z.file('xl/media/logo.png',bytes(LOGO_PNG_BASE64));return z.generateAsync({type:'blob',compression:'DEFLATE'});}
// PDF en una sola pagina CARTA: imagen completa de la hoja HTML.
// Renderizado Canvas sin enlaces externos; trabaja al abrir el HTML con doble clic.
// Word y Excel se generan por separado como tablas/celdas editables.
const PDF_W_PT=612,PDF_H_PT=792;
function crearPDFJpeg(jpeg,width,height){
 const chunks=[];let pos=0;const refs=[0];
 const encoder=new TextEncoder();
 const write=x=>{const v=typeof x==='string'?encoder.encode(x):x;chunks.push(v);pos+=v.length;};
 const add=(n,t)=>{refs[n]=pos;write(`${n} 0 obj\n${t}\nendobj\n`);};
 write('%PDF-1.4\n%');write(new Uint8Array([0xe2,0xe3,0xcf,0xd3]));write('\n');
 add(1,'<< /Type /Catalog /Pages 2 0 R >>');
 add(2,'<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
 add(3,'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>');
 refs[4]=pos;write(`4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${width} /Height ${height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.length} >>\nstream\n`);write(jpeg);write('\nendstream\nendobj\n');
 const op='q\n612 0 0 792 0 0 cm\n/Im1 Do\nQ\n';
 add(5,`<< /Length ${encoder.encode(op).length} >>\nstream\n${op}endstream`);
 const xref=pos;write('xref\n0 6\n0000000000 65535 f \n');
 for(let n=1;n<=5;n++)write(String(refs[n]).padStart(10,'0')+' 00000 n \n');
 write(`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`);
 const all=new Uint8Array(pos);let off=0;for(const c of chunks){all.set(c,off);off+=c.length;}return all;
}
function dibujarTextoCanvas(ctx,text,x,y,w,h,el,escala){
 const cs=getComputedStyle(el);const fs=parseFloat(cs.fontSize)||10;
 const weight=Number(cs.fontWeight)>=600?'700':'400';
 ctx.font=`${weight} ${fs}px Arial, Helvetica, sans-serif`;ctx.fillStyle='#111';ctx.textBaseline='alphabetic';
 const pl=parseFloat(cs.paddingLeft)||0,pr=parseFloat(cs.paddingRight)||0,pt=parseFloat(cs.paddingTop)||0;
 const avail=Math.max(1,w-pl-pr);
 let lineHeight=parseFloat(cs.lineHeight);if(!Number.isFinite(lineHeight))lineHeight=fs*1.2;
 const lines=[];
 for(const raw of String(text).replace(/\r/g,'').split('\n')){
   if(!raw.trim()){lines.push('');continue;}
   let current='';
   for(const word of raw.split(/\s+/)){
     if(ctx.measureText(word).width>avail){
       if(current){lines.push(current);current='';}
       let fragment='';
       for(const char of Array.from(word)){
         if(fragment&&ctx.measureText(fragment+char).width>avail){lines.push(fragment);fragment=char;}
         else fragment+=char;
       }
       current=fragment;continue;
     }
     const next=current?current+' '+word:word;
     if(current&&ctx.measureText(next).width>avail){lines.push(current);current=word;}else{current=next;}
   }
   if(current)lines.push(current);
 }
 if(!lines.length)return;
 const total=lines.length*lineHeight;
 let top=y+pt;
 if(cs.alignItems==='center'||cs.justifyContent==='center'&&cs.display.includes('grid'))top=y+(h-total)/2;
 else if(cs.alignItems==='flex-end')top=y+h-total-(parseFloat(cs.paddingBottom)||0);
 top=Math.max(y,top);
 const align=cs.textAlign;
 lines.forEach((line,i)=>{
    if(!line)return;
    let tx=x+pl;const m=ctx.measureText(line).width;
    if(align==='center'||cs.justifyContent==='center'||cs.justifyItems==='center')tx+=Math.max(0,(avail-m)/2);
    else if(align==='right')tx+=Math.max(0,avail-m);
    // Mantiene el tamaño de los datos y respeta la base de cada casilla.
    const baseline=top+i*lineHeight+fs*.85;
    ctx.fillText(line,tx,baseline,avail);
 });
}
async function capturarHojaCanvas(){
 const page=document.getElementById('printPage');if(!page)throw Error('No se encontró la hoja de impresión.');
 const calidad=3;const canvas=document.createElement('canvas');canvas.width=816*calidad;canvas.height=1056*calidad;
 const ctx=canvas.getContext('2d',{alpha:false});if(!ctx)throw Error('No se pudo preparar la imagen del PDF.');
 ctx.scale(calidad,calidad);ctx.fillStyle='#fff';ctx.fillRect(0,0,816,1056);
 const base=page.getBoundingClientRect();const factor=base.width/816;
 if(!factor||!Number.isFinite(factor))throw Error('La vista previa no tiene medidas válidas.');
 const area=el=>{const r=el.getBoundingClientRect();return {x:(r.left-base.left)/factor,y:(r.top-base.top)/factor,w:r.width/factor,h:r.height/factor};};
 // Cada borde de la hoja se dibuja una sola vez, sin añadir marcos nuevos.
 const bordes='.page-frame,.select-row,.select-row>b,.date-underline,.main-doc-table,.table-heading,.sector-document,.sector-caption,.doc-line,.line-label,.signatures-document,.sign-half,.sign-value';
 for(const el of page.querySelectorAll(bordes)){
  const r=area(el),style=getComputedStyle(el);
  for(const side of ['Top','Right','Bottom','Left']){
   const size=parseFloat(style[`border${side}Width`])||0;
   if(size<=0||style[`border${side}Style`]==='none')continue;
   ctx.strokeStyle=style[`border${side}Color`]||'#111';ctx.lineWidth=size;
   ctx.beginPath();if(side==='Top'){ctx.moveTo(r.x,r.y);ctx.lineTo(r.x+r.w,r.y);}
   if(side==='Right'){ctx.moveTo(r.x+r.w,r.y);ctx.lineTo(r.x+r.w,r.y+r.h);}
   if(side==='Bottom'){ctx.moveTo(r.x,r.y+r.h);ctx.lineTo(r.x+r.w,r.y+r.h);}
   if(side==='Left'){ctx.moveTo(r.x,r.y);ctx.lineTo(r.x,r.y+r.h);}
   ctx.stroke();
  }
 }
 // Cuadrados vacíos con contorno; seleccionados con relleno negro y X blanca.
 for(const sq of page.querySelectorAll('.square')){
  const r=area(sq);const on=sq.classList.contains('on');ctx.strokeStyle='#111';ctx.lineWidth=1;
  if(on){ctx.fillStyle='#111';ctx.fillRect(r.x,r.y,r.w,r.h);}else{ctx.strokeRect(r.x+.3,r.y+.3,r.w-.6,r.h-.6);}
  if(on){ctx.fillStyle='#fff';ctx.font='bold 9px Arial';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('X',r.x+r.w/2,r.y+r.h/2+.5);ctx.textAlign='left';ctx.textBaseline='alphabetic';}
 }
 // Texto real de cada etiqueta y valor, no se superpone ni se convierte a negrita.
 const textos='.doc-title,.date-block b,.date-block .doc-value,.select-row>b,.choice-label,.table-heading,.sector-caption,.line-label,.doc-value,.doc-material-text,.sign-head,.sign-line>b,.document-note';
 for(const el of page.querySelectorAll(textos)){
  if(!el.textContent.trim())continue;
  const r=area(el);const text=el.textContent.trim();dibujarTextoCanvas(ctx,text,r.x,r.y,r.w,r.h,el,calidad);
 }
 if(typeof LOGO_PNG_BASE64!=='string'||!LOGO_PNG_BASE64)throw Error('Falta el logo integrado.');
 const logo=new Image();logo.src='data:image/png;base64,'+LOGO_PNG_BASE64;
 try{await logo.decode();}catch(e){throw Error('No se pudo dibujar el logo en el PDF.');}
 const lr=area(page.querySelector('.doc-logo'));ctx.drawImage(logo,lr.x,lr.y,lr.w,lr.h);
 return canvas;
}
async function createPdf(){
 const canvas=await capturarHojaCanvas();
 let uri;try{uri=canvas.toDataURL('image/jpeg',.95);}catch(e){throw Error('No fue posible crear la imagen del PDF: '+(e.message||String(e)));}
 const jpeg=bytes(uri.split(',')[1]);
 const pdf=crearPDFJpeg(jpeg,canvas.width,canvas.height);
 return new Blob([pdf],{type:'application/pdf'});
}
window.exportarConduce=async function(d,extension){let blob;switch(extension){case 'docx':blob=await createWord(d);break;case 'xlsx':blob=await createExcel(d);break;case 'pdf':blob=await createPdf();break;default:throw Error('Formato desconocido');}if(!(blob instanceof Blob)||blob.size<1000)throw Error('El archivo generado está vacío o incompleto.');
if((extension==='docx'||extension==='xlsx')&&typeof JSZip!=='undefined'){
  const prueba=await JSZip.loadAsync(blob);
  const obligatorio=extension==='docx'?'word/document.xml':'xl/worksheets/sheet1.xml';
  if(!prueba.file(obligatorio))throw Error('El archivo editable no contiene su documento principal.');
}
await descargar(blob,basename(d)+'.'+extension);return blob;};
window.FormularioExportadores={word:createWord,excel:createExcel,pdf:createPdf};
})();
