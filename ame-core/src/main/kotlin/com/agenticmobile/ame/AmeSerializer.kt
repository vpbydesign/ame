package com.agenticmobile.ame

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Serializes and deserializes AmeNode trees and AmeAction objects to/from JSON.
 *
 * Uses kotlinx.serialization with sealed interface polymorphism.
 * The class discriminator is "_type" to avoid collision with AmeNode.Input's
 * "type" property (InputType). kotlinx.serialization requires the discriminator
 * key name to not collide with any property name in sealed subtypes.
 *
 * Configuration:
 * - ignoreUnknownKeys = true: forward-compatible deserialization
 * - encodeDefaults = false: compact JSON (default values omitted)
 * - classDiscriminator = "_type": avoids Input.type property collision
 *
 * Key ordering: all JSON output uses sorted keys (alphabetical) to produce
 * canonical output matching Swift's JSONEncoder(.sortedKeys) and aligning
 * with RFC 8785 (JSON Canonicalization Scheme) for ASCII property names.
 * kotlinx.serialization does not support sorted keys natively, so a
 * post-processing step recursively sorts JsonObject keys after serialization.
 */
object AmeSerializer {

    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = false
        classDiscriminator = "_type"
    }

    private val prettyJson: Json = Json(from = json) {
        prettyPrint = true
    }

    /**
     * Diagnostic exception produced by [fromJsonOrError] / [actionFromJsonOrError]
     * when JSON decoding fails. Wraps the underlying serialization or
     * IO exception so hosts can distinguish invalid JSON, schema mismatch,
     * and unexpected runtime failures without losing the original cause.
     *
     * Lifts the diagnostic out of the previous
     * "swallow into null" path while keeping the legacy nullable APIs for
     * backward compatibility.
     */
    class SerializationException(message: String, cause: Throwable? = null) : Exception(message, cause)

    fun toJson(node: AmeNode): String =
        canonicalize(json.encodeToString(AmeNode.serializer(), node))

    /**
     * Decodes [jsonString] into an [AmeNode]. Returns `null` on any failure
     * for backward compatibility. Hosts that need failure diagnostics
     * should call [fromJsonOrError] instead.
     */
    fun fromJson(jsonString: String): AmeNode? = fromJsonOrError(jsonString).getOrNull()

    /**
     * Diagnostic-bearing counterpart to [fromJson]. Returns
     * [Result.success] with the decoded [AmeNode] on success, or
     * [Result.failure] wrapping a [SerializationException] that names
     * the failure mode and carries the original cause.
     *
     * The previous nullable [fromJson] swallowed every
     * failure into a single `null` return, so hosts could not distinguish
     * invalid JSON, schema mismatch, missing root, or runtime errors. This
     * API is additive; the legacy [fromJson] stays unchanged.
     */
    fun fromJsonOrError(jsonString: String): Result<AmeNode> = try {
        Result.success(json.decodeFromString(AmeNode.serializer(), jsonString))
    } catch (e: kotlinx.serialization.SerializationException) {
        Result.failure(SerializationException("AME JSON decoding failed: ${e.message}", e))
    } catch (e: Exception) {
        Result.failure(SerializationException("Unexpected error during AME decoding: ${e.message}", e))
    }

    fun treeToJson(node: AmeNode, prettyPrint: Boolean = false): String {
        val format = if (prettyPrint) prettyJson else json
        return canonicalize(format.encodeToString(AmeNode.serializer(), node), prettyPrint)
    }

    fun actionToJson(action: AmeAction): String =
        canonicalize(json.encodeToString(AmeAction.serializer(), action))

    /**
     * Decodes [jsonString] into an [AmeAction]. Returns `null` on any
     * failure for backward compatibility. See [actionFromJsonOrError] for
     * the diagnostic variant.
     */
    fun actionFromJson(jsonString: String): AmeAction? = actionFromJsonOrError(jsonString).getOrNull()

    /**
     * Diagnostic-bearing counterpart to [actionFromJson]. Mirrors
     * [fromJsonOrError] for action payloads so cross-runtime hosts can
     * use a single failure-handling pattern for both nodes and actions.
     */
    fun actionFromJsonOrError(jsonString: String): Result<AmeAction> = try {
        Result.success(json.decodeFromString(AmeAction.serializer(), jsonString))
    } catch (e: kotlinx.serialization.SerializationException) {
        Result.failure(SerializationException("AME action JSON decoding failed: ${e.message}", e))
    } catch (e: Exception) {
        Result.failure(SerializationException("Unexpected error during AME action decoding: ${e.message}", e))
    }

    private fun canonicalize(jsonString: String, prettyPrint: Boolean = false): String {
        val element = Json.parseToJsonElement(jsonString)
        val sorted = sortKeys(element)
        val format = if (prettyPrint) prettyJson else json
        return format.encodeToString(JsonElement.serializer(), sorted)
    }

    private fun sortKeys(element: JsonElement): JsonElement = when (element) {
        is JsonObject -> JsonObject(
            element.entries
                .sortedBy { it.key }
                .associate { (k, v) -> k to sortKeys(v) }
        )
        is JsonArray -> JsonArray(element.map { sortKeys(it) })
        is JsonPrimitive -> element
    }
}
