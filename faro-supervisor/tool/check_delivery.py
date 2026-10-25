"""Checks executable here: native SQLite schema + source package integrity.

This script does not compile Dart, launch Flutter, or run an Android device.
"""
import json
import re
import sqlite3
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = json.loads((ROOT / 'tool/reference/model.json').read_text())
EXT = json.loads((ROOT / 'tool/reference/extensions.json').read_text())

class SqlSchemaTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.executescript((ROOT / 'tool/schema.sql').read_text())
        self.db.execute("INSERT INTO PM_Roles(ID,CodigoRol,NombreRol,Activo) VALUES(1,'GERENCIA','Supervisor',1)")
        self.db.execute("INSERT INTO PM_Usuarios(ID,UPN,NombreMostrado,RolID,Activo,AltaUTC) VALUES(1,'OPERADOR_DEMO','Supervisor Demo',1,1,'2026-10-25T12:00:00Z')")
        self.db.execute("INSERT INTO PM_Buques(ID,NombreBuque,Activo) VALUES(1,'Buque Demo',1)")
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def create_scale(self, code='CALL-DEMO', vessel=1):
        self.db.execute('INSERT INTO PM_Escalas(ID,CallKey,BuqueID,FechaETA,EstadoProyecto,VersionProyecto) VALUES(1,?,?,?, ?,1)', (code,vessel,'2026-10-25','Pendiente'))

    def test_table_and_field_contract(self):
        actual = {r[0] for r in self.db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertEqual(actual - {'sqlite_sequence', 'local_settings'}, set(MODEL['tablas']))
        expected = MODEL['contratos_campos'] + EXT['fields']
        total = 0
        for table in MODEL['tablas']:
            fields = {r[1] for r in self.db.execute(f'PRAGMA table_info("{table}")')}
            self.assertEqual(fields, {f['campo'] for f in expected if f['tabla'] == table})
            total += len(fields)
        self.assertEqual(total, 323)

    def test_foreign_keys_enabled_and_complete(self):
        self.assertEqual(self.db.execute('PRAGMA foreign_keys').fetchone()[0], 1)
        actual=set()
        for table in MODEL['tablas']:
            for r in self.db.execute(f'PRAGMA foreign_key_list("{table}")'):
                actual.add((table,r[3],r[2],r[4]))
        expected={(r['origen'],r['campo'],r['destino'],r['clave']) for r in MODEL['relaciones']+EXT['relations']}
        self.assertEqual(actual, expected)
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(), [])

    def test_invalid_reference_is_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.create_scale(vessel=999)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM PM_Escalas').fetchone()[0],0)

    def test_counts_reject_fractions_and_negative_values(self):
        self.create_scale()
        for number in [1.5,-1]:
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute('INSERT INTO PM_VaciosDestino(EscalaID,PuertoDestino,Cantidad) VALUES(1,?,?)',('Puerto Demo',number))

    def test_booleans_and_required_fields(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO PM_Buques(NombreBuque,Activo) VALUES('Buque Demo',2)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO PM_Buques(NombreBuque) VALUES(NULL)')

    def test_uniqueness_and_restrict_delete(self):
        self.create_scale()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO PM_Escalas(CallKey,BuqueID,FechaETA,EstadoProyecto,VersionProyecto) VALUES('CALL-DEMO',1,'2026-10-25','Pendiente',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('DELETE FROM PM_Buques WHERE ID=1')

    def test_rollback_preserves_prior_state(self):
        self.create_scale()
        self.db.commit()
        with self.assertRaises(sqlite3.IntegrityError):
            with self.db:
                self.db.execute("UPDATE PM_Escalas SET EstadoProyecto='EnProceso' WHERE ID=1")
                self.db.execute("INSERT INTO PM_ControlEdicion(EscalaID,EstadoBloqueo,UltimoCambioUTC,VersionControl) VALUES(999,'Tomado','2026-10-25T12:00:00Z',1)")
        self.assertEqual(self.db.execute('SELECT EstadoProyecto FROM PM_Escalas WHERE ID=1').fetchone()[0], 'Pendiente')

class AndroidPackageTests(unittest.TestCase):
    def test_android_manifest_is_offline(self):
        manifest=ET.parse(ROOT/'android/app/src/main/AndroidManifest.xml').getroot()
        self.assertFalse(manifest.findall('uses-permission'))
        application=manifest.find('application')
        ns='{http://schemas.android.com/apk/res/android}'
        self.assertEqual(application.attrib[ns+'allowBackup'],'false')
        self.assertEqual(application.attrib[ns+'fullBackupContent'],'false')
        self.assertEqual(application.find('activity').attrib[ns+'name'],'.MainActivity')

    def test_android_xml_and_package_names(self):
        for p in (ROOT/'android/app/src/main/res').rglob('*.xml'):
            ET.parse(p)
        gradle=(ROOT/'android/app/build.gradle.kts').read_text()
        self.assertIn('applicationId = "local.pmbuques.supervisor"', gradle)
        kotlin=(ROOT/'android/app/src/main/kotlin/local/pmbuques/supervisor/MainActivity.kt').read_text()
        self.assertIn('package local.pmbuques.supervisor',kotlin)

    def test_source_imports_resolve_locally(self):
        for p in (ROOT/'lib').rglob('*.dart'):
            text=p.read_text()
            for uri in re.findall(r"(?:import|export)\s+['\"]([^'\"]+)['\"]",text):
                if uri.startswith('package:pm_buques_supervisor/'):
                    target=ROOT/'lib'/uri.split('package:pm_buques_supervisor/')[1]
                    self.assertTrue(target.is_file(),(p,uri))
                elif ':' not in uri:
                    self.assertTrue((p.parent/uri).is_file(),(p,uri))

    def test_no_embedded_corporate_endpoints_or_credentials(self):
        for p in (ROOT/'lib').rglob('*.dart'):
            text=p.read_text()
            self.assertNotRegex(text,r'https?://[^\s\"\']+\.sharepoint\.com')
            self.assertNotRegex(text,r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----')
            self.assertNotRegex(text,r'(?i)(?:client_secret|access_token|refresh_token)\s*[:=]\s*[\"\'][^\"\']{8,}')

if __name__ == '__main__':
    suite=unittest.defaultTestLoader.loadTestsFromModule(__import__(__name__))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    report={
        'native_sqlite_and_source_checks':{'executed':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'status':'PASS' if result.wasSuccessful() else 'FAIL'},
        'dart_analysis':'NOT_EXECUTED_FLUTTER_SDK_UNAVAILABLE',
        'dart_repository_tests':'NOT_EXECUTED_FLUTTER_SDK_UNAVAILABLE',
        'flutter_widget_tests':'NOT_EXECUTED_FLUTTER_SDK_UNAVAILABLE',
        'android_apk_build':'NOT_EXECUTED_FLUTTER_ANDROID_SDK_UNAVAILABLE',
        'android_device_test':'NOT_EXECUTED',
        'network_limitation':'SDK download could not reach the execution environment proxy.',
    }
    (ROOT/'RESULTADO_VERIFICACION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
