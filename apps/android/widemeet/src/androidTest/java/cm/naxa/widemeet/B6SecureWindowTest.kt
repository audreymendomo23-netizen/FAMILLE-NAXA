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
                try {
                    // A grid across the interior is resilient to transient status/navigation overlays.
                    var hits=0
                    for(x in 2..8) for(y in 2..8) {
                        val pixel=bitmap.getPixel(bitmap.width*x/10,bitmap.height*y/10)
                        if(Color.red(pixel)>200 && Color.blue(pixel)>200 && Color.green(pixel)<60) hits++
                    }
                    return hits>=3
                }
                finally { bitmap.recycle() }
            }
            try {
                instrumentation.waitForIdleSync()
                var control=false
                repeat(60) { if(!control){Thread.sleep(200);control=visible()} }
                assertTrue("Synthetic capture positive control must be visible",control)
            } finally { scenario.onActivity { it.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) } }
            instrumentation.waitForIdleSync();Thread.sleep(1000)
            repeat(5) {
                assertFalse("Secure content must not be visible to system screenshot",visible())
                Thread.sleep(150)
            }
        }
    }
}
