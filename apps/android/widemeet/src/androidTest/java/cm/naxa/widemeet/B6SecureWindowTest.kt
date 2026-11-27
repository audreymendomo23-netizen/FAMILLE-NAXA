package cm.naxa.widemeet
import android.view.WindowManager
import android.graphics.Color
import android.widget.FrameLayout
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class B6SecureWindowTest {
    @Test fun secureFlagIsPresentBeforeAndAfterRecreation() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                assertTrue(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
            }
            scenario.recreate()
            scenario.onActivity { activity ->
                assertTrue(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
            }
        }
    }
    @Test fun secureWindowHidesKnownPixelsFromSystemCapture() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            // Only this synthetic test screen is deliberately made non-secure as a positive control.
            scenario.onActivity { activity ->
                activity.setContentView(FrameLayout(activity).apply { setBackgroundColor(Color.MAGENTA) })
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            fun visible(): Boolean {
                val bitmap=instrumentation.uiAutomation.takeScreenshot() ?: return false
                try { val pixel=bitmap.getPixel(bitmap.width/2,bitmap.height/2);return Color.red(pixel)>200 && Color.blue(pixel)>200 && Color.green(pixel)<60 }
                finally { bitmap.recycle() }
            }
            try {
                instrumentation.waitForIdleSync()
                var control=false
                repeat(15) { if(!control){Thread.sleep(150);control=visible()} }
                assertTrue("Synthetic capture positive control must be visible",control)
            } finally { scenario.onActivity { it.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) } }
            instrumentation.waitForIdleSync();Thread.sleep(600)
            assertFalse("Secure content must not be visible to system screenshot",visible())
        }
    }
}
