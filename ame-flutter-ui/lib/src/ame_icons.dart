import 'package:flutter/material.dart';

/// Maps Material icon name strings (snake_case) to Flutter [IconData] objects.
///
/// The AME Icon node carries a string `name` property (e.g., `"star"`, `"email"`).
/// This registry resolves those strings to platform icon objects at render time.
///
/// Unknown names return [Icons.help_outline] as a fallback.
class AmeIcons {
  AmeIcons._();

  static IconData resolve(String name) => _registry[name] ?? Icons.help_outline;

  static String contentDescription(String name) => name.replaceAll('_', ' ');

  static int get registryCount => _registry.length;

  static const _registry = <String, IconData>{
    // Navigation
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'close': Icons.close,
    'menu': Icons.menu,
    'home': Icons.home,

    // Actions
    'check': Icons.check,
    'check_circle': Icons.check_circle,
    'add': Icons.add,
    'delete': Icons.delete,
    'edit': Icons.edit,
    'search': Icons.search,
    'share': Icons.share,
    'bookmark': Icons.bookmark,
    'favorite': Icons.favorite,
    'content_copy': Icons.content_copy,
    'send': Icons.send,

    // Communication
    'email': Icons.email,
    'phone': Icons.phone,
    'message': Icons.message,
    'chat': Icons.chat,
    'notifications': Icons.notifications,

    // Content
    'star': Icons.star,
    'star_outline': Icons.star_outline,
    'info': Icons.info,
    'warning': Icons.warning,
    'error': Icons.error,

    // Places
    'place': Icons.place,
    'location_on': Icons.location_on,
    'directions': Icons.directions,
    'map': Icons.map,
    'restaurant': Icons.restaurant,

    // Time & Calendar
    'event': Icons.event,
    'schedule': Icons.schedule,
    'access_time': Icons.access_time,
    'today': Icons.today,
    'calendar_month': Icons.calendar_month,

    // Media
    'play_arrow': Icons.play_arrow,
    'pause': Icons.pause,
    'skip_next': Icons.skip_next,
    'music_note': Icons.music_note,
    'volume_up': Icons.volume_up,

    // Files & Data
    'description': Icons.description,
    'folder': Icons.folder,
    'cloud': Icons.cloud,
    'download': Icons.download,
    'upload': Icons.upload,

    // People
    'person': Icons.person,
    'group': Icons.group,
    'account_circle': Icons.account_circle,

    // Weather — "partly_cloudy_day" has no exact match; cloud is closest
    'partly_cloudy_day': Icons.cloud,
    'sunny': Icons.wb_sunny,
    'wb_sunny': Icons.wb_sunny,

    // Misc
    'settings': Icons.settings,
    'help': Icons.help,
    'visibility': Icons.visibility,
    'lock': Icons.lock,
    'list': Icons.list,
  };
}
