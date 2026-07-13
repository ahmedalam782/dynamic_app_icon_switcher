package com.ahmedalam.dynamic_app_icon_switcher

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Switches the launcher icon by enabling/disabling `activity-alias` components
 * whose class names contain `.icons.`.
 *
 * Naming convention: `<package>.icons.<Name>` (e.g. `.icons.Red`).
 * The default launcher activity is enabled when [iconName] is `"default"`.
 */
class DynamicAppIconSwitcherPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dynamic_app_icon_switcher")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        val context = applicationContext
        if (context == null) {
            result.error(SET_ICON_FAILED, "Plugin is not attached to an engine.", null)
            return
        }

        when (call.method) {
            "supportsAlternateIcons" -> result.success(true)
            "getAvailableIcons" -> result.success(listAlternateIconNames(context))
            "currentIcon" -> result.success(resolveCurrentIcon(context))
            "setIcon" -> {
                val iconName = call.argument<String>("iconName")
                if (iconName.isNullOrBlank()) {
                    result.error(ICON_NOT_FOUND, "iconName must not be empty.", null)
                    return
                }
                try {
                    setIcon(context, iconName)
                    result.success(null)
                } catch (e: IconNotFoundException) {
                    result.error(ICON_NOT_FOUND, e.message, null)
                } catch (e: Exception) {
                    result.error(SET_ICON_FAILED, e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    private fun setIcon(
        context: Context,
        iconName: String,
    ) {
        val pm = context.packageManager
        val packageName = context.packageName
        val aliases = listAliasComponents(context)
        val defaultActivity = findDefaultLauncherActivity(context)
            ?: throw IllegalStateException("Could not resolve the default launcher activity.")

        val normalized = if (iconName.equals("default", ignoreCase = true)) "default" else iconName

        if (normalized != "default") {
            val targetSuffix = ".icons.$normalized"
            val match = aliases.firstOrNull { it.className.endsWith(targetSuffix) }
                ?: throw IconNotFoundException(
                    "No activity-alias found for icon '$normalized'. " +
                        "Expected a component ending with '$targetSuffix'.",
                )

            // Enable target alias first, then disable others + default.
            setEnabled(pm, match, true)
            for (alias in aliases) {
                if (alias != match) {
                    setEnabled(pm, alias, false)
                }
            }
            setEnabled(pm, defaultActivity, false)
        } else {
            setEnabled(pm, defaultActivity, true)
            for (alias in aliases) {
                setEnabled(pm, alias, false)
            }
        }
    }

    private fun resolveCurrentIcon(context: Context): String {
        val pm = context.packageManager
        for (alias in listAliasComponents(context)) {
            val state = pm.getComponentEnabledSetting(alias)
            val enabled =
                state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    (
                        state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT &&
                            isEnabledInManifest(pm, alias)
                    )
            if (enabled) {
                val className = alias.className
                val marker = ".icons."
                val index = className.lastIndexOf(marker)
                if (index >= 0) {
                    return className.substring(index + marker.length)
                }
            }
        }
        return "default"
    }

    private fun listAlternateIconNames(context: Context): List<String> {
        val marker = ".icons."
        return listAliasComponents(context).mapNotNull { component ->
            val className = component.className
            val index = className.lastIndexOf(marker)
            if (index >= 0) className.substring(index + marker.length) else null
        }.distinct()
    }

    private fun listAliasComponents(context: Context): List<ComponentName> {
        val packageName = context.packageName
        val activities = activityInfos(context) ?: return emptyList()
        return activities
            .filter { it.name.contains(".icons.") }
            .map { ComponentName(packageName, it.name) }
    }

    private fun findDefaultLauncherActivity(context: Context): ComponentName? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        // When an alias is active, getLaunchIntentForPackage may resolve to the alias.
        // Prefer the real activity declared without `.icons.` in its name.
        val activities = activityInfos(context) ?: return intent?.component
        val main =
            activities.firstOrNull { info ->
                !info.name.contains(".icons.") &&
                    info.name.endsWith(".MainActivity")
            }
        return if (main != null) {
            ComponentName(context.packageName, main.name)
        } else {
            intent?.component
        }
    }

    private fun activityInfos(context: Context): Array<android.content.pm.ActivityInfo>? {
        val pm = context.packageManager
        val flags =
            PackageManager.GET_ACTIVITIES or
                PackageManager.MATCH_DISABLED_COMPONENTS or
                PackageManager.GET_DISABLED_COMPONENTS
        return try {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(context.packageName, flags).activities
        } catch (_: Exception) {
            null
        }
    }

    private fun setEnabled(
        pm: PackageManager,
        component: ComponentName,
        enabled: Boolean,
    ) {
        pm.setComponentEnabledSetting(
            component,
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun isEnabledInManifest(
        pm: PackageManager,
        component: ComponentName,
    ): Boolean {
        return try {
            val info = pm.getActivityInfo(component, PackageManager.GET_META_DATA)
            info.enabled && info.exported
        } catch (_: Exception) {
            false
        }
    }

    private class IconNotFoundException(
        message: String,
    ) : Exception(message)

    companion object {
        private const val ICON_NOT_FOUND = "ICON_NOT_FOUND"
        private const val SET_ICON_FAILED = "SET_ICON_FAILED"
    }
}
