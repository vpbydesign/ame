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

    fun toJson(node: AmeNode): String =
        canonicalize(json.encodeToString(AmeNode.serializer(), node))

    fun fromJson(jsonString: String): AmeNode? = try {
        json.decodeFromString(AmeNode.serializer(), jsonString)
    } catch (_: Exception) {
        null
    }

    fun treeToJson(node: AmeNode, prettyPrint: Boolean = false): String {
        val format = if (prettyPrint) prettyJson else json
        return canonicalize(format.encodeToString(AmeNode.serializer(), node), prettyPrint)
    }

    fun actionToJson(action: AmeAction): String =
        canonicalize(json.encodeToString(AmeAction.serializer(), action))

    fun actionFromJson(jsonString: String): AmeAction? = try {
        json.decodeFromString(AmeAction.serializer(), jsonString)
    } catch (_: Exception) {
        null
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
