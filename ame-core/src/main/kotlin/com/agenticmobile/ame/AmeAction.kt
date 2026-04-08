package com.agenticmobile.ame

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Actions define what happens when a user interacts with an AME element.
 * They appear as arguments to interactive primitives (primarily btn).
 *
 * The renderer dispatches all actions to the host app via AmeActionHandler.
 * The renderer MUST NOT execute actions directly.
 *
 * See actions.md for the complete specification.
 */
@Serializable
sealed interface AmeAction {

    /**
     * Invoke a named tool through the host app's tool execution pipeline.
     * [args] values may contain `${input.fieldId}` references as literal strings —
     * these are resolved by the renderer at dispatch time, NOT by the parser.
     */
    @Serializable
    @SerialName("tool")
    data class CallTool(
        val name: String,
        val args: Map<String, String> = emptyMap()
    ) : AmeAction

    /** Open a URI using the platform's default handler (geo:, tel:, mailto:, https:, etc.). */
    @Serializable
    @SerialName("uri")
    data class OpenUri(val uri: String) : AmeAction

    /** Navigate to a screen/route within the host application. Route names are app-defined. */
    @Serializable
    @SerialName("nav")
    data class Navigate(val route: String) : AmeAction

    /** Copy a text string to the system clipboard. */
    @Serializable
    @SerialName("copy")
    data class CopyText(val text: String) : AmeAction

    /**
     * Collect all input/toggle values from the current card's subtree,
     * merge with [staticArgs], and dispatch as a CallTool action.
     *
     * Included in the serializable model for persistence even though the
     * renderer converts it to CallTool at dispatch time.
     *
     * [staticArgs] values may contain `${input.fieldId}` references as literal
     * strings — resolved by the renderer at dispatch time.
     */
    @Serializable
    @SerialName("submit")
    data class Submit(
        val toolName: String,
        val staticArgs: Map<String, String> = emptyMap()
    ) : AmeAction
}
