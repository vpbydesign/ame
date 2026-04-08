package com.agenticmobile.ame.compose

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf

/**
 * Manages form input values for AME [Input][com.agenticmobile.ame.AmeNode.Input]
 * and [Toggle][com.agenticmobile.ame.AmeNode.Toggle] nodes within a rendered
 * AME document.
 *
 * The host app creates [AmeFormState] instances and passes them to
 * [AmeRenderer]. The host is responsible for scoping form state lifetime
 * (e.g., keyed by message ID in a ViewModel).
 *
 * Thread safety: all access is expected to occur on the main/UI thread
 * as part of Compose recomposition.
 */
class AmeFormState {

    private val inputValues = mutableMapOf<String, MutableState<String>>()
    private val toggleValues = mutableMapOf<String, MutableState<Boolean>>()

    /**
     * Registers an input field and returns its mutable state.
     *
     * If the field was already registered (e.g., during recomposition),
     * the existing state is returned without resetting its value.
     *
     * @param id Unique form field identifier matching [AmeNode.Input.id].
     * @param defaultValue Initial value for the field. Defaults to `""`.
     * @return [MutableState] that the composable reads and writes.
     */
    fun registerInput(id: String, defaultValue: String = ""): MutableState<String> =
        inputValues.getOrPut(id) { mutableStateOf(defaultValue) }

    /**
     * Registers a toggle field and returns its mutable state.
     *
     * If the field was already registered, the existing state is returned.
     *
     * @param id Unique form field identifier matching [AmeNode.Toggle.id].
     * @param defaultValue Initial checked state. Defaults to `false`.
     * @return [MutableState] that the composable reads and writes.
     */
    fun registerToggle(id: String, defaultValue: Boolean = false): MutableState<Boolean> =
        toggleValues.getOrPut(id) { mutableStateOf(defaultValue) }

    /**
     * Collects all current form values into a flat map.
     *
     * Input values are included as-is. Toggle boolean values are
     * converted to `"true"` or `"false"` strings.
     *
     * @return Map of field ID to current string value.
     */
    fun collectValues(): Map<String, String> = buildMap {
        inputValues.forEach { (id, state) -> put(id, state.value) }
        toggleValues.forEach { (id, state) -> put(id, state.value.toString()) }
    }

    /**
     * Resolves `${input.fieldId}` references in action argument values
     * against the current form state.
     *
     * The pattern `\$\{input\.(\w+)\}` is matched in each value string.
     * If the referenced field ID exists in the form state, the token is
     * replaced with the current value. If not found, the token is left
     * as-is (unreplaced) per actions.md § Form Data Resolution.
     *
     * @param args Original argument map (e.g., from [AmeAction.Submit.staticArgs]).
     * @return New map with all resolvable `${input.*}` references replaced.
     */
    fun resolveInputReferences(args: Map<String, String>): Map<String, String> {
        val collected = collectValues()
        return args.mapValues { (_, value) ->
            INPUT_REF_REGEX.replace(value) { match ->
                val fieldId = match.groupValues[1]
                collected[fieldId] ?: match.value
            }
        }
    }

    companion object {
        private val INPUT_REF_REGEX = Regex("""\$\{input\.(\w+)\}""")
    }
}
