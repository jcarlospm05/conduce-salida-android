package local.sentinel.planner;

import android.graphics.Bitmap;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public final class PlannerSmokeTest {
    private String js(ActivityScenario<MainActivity> scenario, String script) throws Exception {
        AtomicReference<String> result = new AtomicReference<>();
        CountDownLatch done = new CountDownLatch(1);
        scenario.onActivity(activity -> activity.webForTest().evaluateJavascript(script, value -> { result.set(value); done.countDown(); }));
        assertTrue("WebView no respondió", done.await(10, TimeUnit.SECONDS));
        return result.get();
    }
    private void ready(ActivityScenario<MainActivity> scenario) throws Exception {
        long deadline = System.currentTimeMillis() + 20000;
        while (System.currentTimeMillis() < deadline) {
            if ("true".equals(js(scenario, "document.querySelectorAll('.task').length>0"))) return;
            Thread.sleep(100);
        }
        fail("El planificador no mostró tareas locales");
    }
    @Test public void localPageRendersAndNewTaskPersists() throws Exception {
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            ready(scenario);
            assertEquals("\"https://appassets.androidplatform.net\"", js(scenario, "location.origin"));
            assertEquals("true", js(scenario, "typeof PlannerBridge.saveFile==='function'&&typeof PlannerBridge.shareFile==='function'&&typeof PlannerBridge.copyText==='function'&&typeof PlannerBridge.openMasterDocument==='function'"));
            String title = "QA Android " + System.currentTimeMillis();
            assertEquals("true", js(scenario, "document.getElementById('newTask').click();document.getElementById('taskDialog').open"));
            js(scenario, "document.getElementById('fTitle').value='" + title + "';document.getElementById('taskForm').requestSubmit();");
            assertEquals("true", js(scenario, "document.getElementById('taskList').textContent.includes('" + title + "')"));
            js(scenario, "document.getElementById('generateReport').click();document.getElementById('rTitle').value='Contexto Android';document.getElementById('rNotes').value='Preparar cambios Codex';document.getElementById('reportForm').requestSubmit();");
            assertEquals("true", js(scenario, "JSON.parse(localStorage.getItem('sentinel-project-tracker-v1')).reports[0].contextTxt.includes('Preparar cambios Codex')"));
            scenario.recreate();
            ready(scenario);
            assertEquals("true", js(scenario, "document.getElementById('taskList').textContent.includes('" + title + "')"));
            assertEquals("true", js(scenario, "JSON.parse(localStorage.getItem('sentinel-project-tracker-v1')).reports[0].contextTxt.includes('Preparar cambios Codex')"));
            Bitmap screenshot = InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();
            if (screenshot != null) {
                File target = new File(InstrumentationRegistry.getInstrumentation().getTargetContext().getFilesDir(), "planner-smoke.png");
                try (FileOutputStream out = new FileOutputStream(target)) { screenshot.compress(Bitmap.CompressFormat.PNG, 100, out); }
                screenshot.recycle();
            }
        }
    }
    @Test public void exportFilesAreUtf8AndNamesAreSanitized() throws Exception {
        assertFalse(MainActivity.safeName("../../unsafe.json").contains("/"));
        assertFalse(MainActivity.safeName("..\\unsafe.json").contains("\\"));
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            ready(scenario);
            AtomicReference<File> file = new AtomicReference<>();
            AtomicReference<Exception> failure = new AtomicReference<>();
            String data = "{\"tasks\":[{\"title\":\"Planificación marítima ✓\"}]}";
            scenario.onActivity(activity -> { try { file.set(activity.prepareFile("../../test.json", data)); } catch (Exception e) { failure.set(e); } });
            if (failure.get() != null) throw failure.get();
            assertEquals(data, new String(Files.readAllBytes(file.get().toPath()), StandardCharsets.UTF_8));
            assertTrue(file.get().delete());
        }
    }
}
