package com.ahmedalam.dynamic_app_icon_switcher

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Basic unit test for method routing. Full icon switching requires an Android
 * Context / PackageManager and is covered by the example app on device.
 */
internal class DynamicAppIconSwitcherPluginTest {
    @Test
    fun onMethodCall_unknownMethod_returnsNotImplemented() {
        val plugin = DynamicAppIconSwitcherPlugin()

        val call = MethodCall("unknownMethod", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
    }
}
