package com.agenticmobile.ame.compose

import com.agenticmobile.ame.AmeAction

/**
 * Integration interface for host applications to receive action events
 * from rendered AME components.
 *
 * The AME renderer dispatches all actions through this handler. The
 * renderer MUST NOT execute actions directly — it delegates to the host
 * app, which decides whether to execute, confirm, or block the action
 * based on its own trust and safety policies.
 *
 * Per actions.md: [AmeAction.Submit] is resolved to [AmeAction.CallTool]
 * by the renderer before dispatch. The handler will never receive a
 * Submit action — only CallTool with merged form values.
 *
 * Usage:
 * ```
 * val handler = AmeActionHandler { action ->
 *     when (action) {
 *         is AmeAction.CallTool -> toolExecutor.execute(action.name, action.args)
 *         is AmeAction.OpenUri -> context.startActivity(Intent(ACTION_VIEW, Uri.parse(action.uri)))
 *         is AmeAction.Navigate -> navController.navigate(action.route)
 *         is AmeAction.CopyText -> clipboard.setPrimaryClip(ClipData.newPlainText("", action.text))
 *         is AmeAction.Submit -> error("Submit is resolved before dispatch")
 *     }
 * }
 * ```
 */
fun interface AmeActionHandler {
    fun handleAction(action: AmeAction)
}
