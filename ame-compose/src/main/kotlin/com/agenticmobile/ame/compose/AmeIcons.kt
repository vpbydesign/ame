package com.agenticmobile.ame.compose

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Directions
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Help
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Message
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarOutline
import androidx.compose.material.icons.filled.Today
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Maps Material icon name strings (snake_case, from the Material Icons catalog)
 * to Compose [ImageVector] objects.
 *
 * The AME [Icon][com.agenticmobile.ame.AmeNode.Icon] node carries a string
 * `name` property (e.g., `"star"`, `"email"`). This registry resolves those
 * strings to platform icon objects at render time.
 *
 * Unknown names return a fallback question-mark icon ([Icons.Filled.HelpOutline]).
 */
object AmeIcons {

    private val registry: Map<String, ImageVector> = buildMap {
        // ── Navigation ─────────────────────────────────────────────
        put("arrow_back", Icons.AutoMirrored.Filled.ArrowBack)
        put("arrow_forward", Icons.AutoMirrored.Filled.ArrowForward)
        put("close", Icons.Filled.Close)
        put("menu", Icons.Filled.Menu)
        put("home", Icons.Filled.Home)

        // ── Actions ────────────────────────────────────────────────
        put("check", Icons.Filled.Check)
        put("check_circle", Icons.Filled.CheckCircle)
        put("add", Icons.Filled.Add)
        put("delete", Icons.Filled.Delete)
        put("edit", Icons.Filled.Edit)
        put("search", Icons.Filled.Search)
        put("share", Icons.Filled.Share)
        put("bookmark", Icons.Filled.Bookmark)
        put("favorite", Icons.Filled.Favorite)
        put("content_copy", Icons.Filled.ContentCopy)
        put("send", Icons.AutoMirrored.Filled.Send)

        // ── Communication ──────────────────────────────────────────
        put("email", Icons.Filled.Email)
        put("phone", Icons.Filled.Phone)
        put("message", Icons.Filled.Message)
        put("chat", Icons.Filled.Chat)
        put("notifications", Icons.Filled.Notifications)

        // ── Content ────────────────────────────────────────────────
        put("star", Icons.Filled.Star)
        put("star_outline", Icons.Filled.StarOutline)
        put("info", Icons.Filled.Info)
        put("warning", Icons.Filled.Warning)
        put("error", Icons.Filled.Error)

        // ── Places ─────────────────────────────────────────────────
        put("place", Icons.Filled.Place)
        put("location_on", Icons.Filled.LocationOn)
        put("directions", Icons.Filled.Directions)
        put("map", Icons.Filled.Map)
        put("restaurant", Icons.Filled.Restaurant)

        // ── Time & Calendar ────────────────────────────────────────
        put("event", Icons.Filled.Event)
        put("schedule", Icons.Filled.Schedule)
        put("access_time", Icons.Filled.AccessTime)
        put("today", Icons.Filled.Today)
        put("calendar_month", Icons.Filled.CalendarMonth)

        // ── Media ──────────────────────────────────────────────────
        put("play_arrow", Icons.Filled.PlayArrow)
        put("pause", Icons.Filled.Pause)
        put("skip_next", Icons.Filled.SkipNext)
        put("music_note", Icons.Filled.MusicNote)
        put("volume_up", Icons.Filled.VolumeUp)

        // ── Files & Data ───────────────────────────────────────────
        put("description", Icons.Filled.Description)
        put("folder", Icons.Filled.Folder)
        put("cloud", Icons.Filled.Cloud)
        put("download", Icons.Filled.Download)
        put("upload", Icons.Filled.Upload)

        // ── People ─────────────────────────────────────────────────
        put("person", Icons.Filled.Person)
        put("group", Icons.Filled.Group)
        put("account_circle", Icons.Filled.AccountCircle)

        // ── Weather ────────────────────────────────────────────────
        // "partly_cloudy_day" has no exact match; Cloud is the closest
        put("partly_cloudy_day", Icons.Filled.Cloud)
        put("sunny", Icons.Filled.WbSunny)
        put("wb_sunny", Icons.Filled.WbSunny)

        // ── Misc ───────────────────────────────────────────────────
        put("settings", Icons.Filled.Settings)
        put("help", Icons.Filled.Help)
        put("visibility", Icons.Filled.Visibility)
        put("lock", Icons.Filled.Lock)
        put("list", Icons.AutoMirrored.Filled.List)
    }

    /**
     * Resolves a Material icon name to an [ImageVector].
     *
     * @param name Snake_case icon name (e.g., `"check_circle"`, `"star"`).
     * @return The matching [ImageVector], or [Icons.Filled.HelpOutline] if
     *         the name is not in the registry.
     */
    fun resolve(name: String): ImageVector =
        registry[name] ?: Icons.Filled.HelpOutline

    /**
     * Derives a human-readable content description from an icon name
     * by replacing underscores with spaces.
     *
     * Per primitives.md accessibility guidance: `"check_circle"` becomes
     * `"check circle"`.
     */
    fun contentDescription(name: String): String =
        name.replace('_', ' ')
}
