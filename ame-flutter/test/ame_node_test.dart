import 'package:test/test.dart';
import 'package:ame_flutter/ame_flutter.dart';

void main() {
  void assertRoundTrip(AmeNode node) {
    final json = AmeSerializer.toJson(node);
    final restored = AmeSerializer.fromJson(json);
    expect(restored, isNotNull, reason: 'Deserialization returned null for: $json');
    expect(restored, equals(node), reason: 'Round-trip failed for: $json');
  }

  void assertActionRoundTrip(AmeAction action) {
    final json = AmeSerializer.actionToJson(action);
    final restored = AmeSerializer.actionFromJson(json);
    expect(restored, isNotNull, reason: 'Action deserialization returned null for: $json');
    expect(restored, equals(action), reason: 'Action round-trip failed for: $json');
  }

  // ── Layout Primitives ──────────────────────────────────────────────

  group('Layout Primitives', () {
    test('roundTripCol', () {
      assertRoundTrip(const AmeCol(
        children: [
          AmeTxt(text: 'Hello', style: TxtStyle.title),
          AmeTxt(text: 'World'),
        ],
        align: Align.center,
      ));
    });

    test('roundTripColDefaults', () {
      const node = AmeCol(children: [AmeTxt(text: 'A')]);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"align"'), isFalse,
          reason: 'Default align should not be encoded: $json');
    });

    test('roundTripRow', () {
      assertRoundTrip(const AmeRow(
        children: [AmeTxt(text: 'Left'), AmeTxt(text: 'Right')],
        align: Align.spaceBetween,
        gap: 16,
      ));
    });

    test('roundTripRowDefaults', () {
      const node = AmeRow(children: [AmeTxt(text: 'Item')]);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"gap"'), isFalse,
          reason: 'Default gap should not be encoded: $json');
      expect(json.contains('"align"'), isFalse,
          reason: 'Default align should not be encoded: $json');
    });
  });

  // ── Content Primitives ─────────────────────────────────────────────

  group('Content Primitives', () {
    test('roundTripTxt', () {
      assertRoundTrip(
          const AmeTxt(text: 'Hello World', style: TxtStyle.headline, maxLines: 2));
    });

    test('roundTripTxtDefaults', () {
      const node = AmeTxt(text: 'Simple text');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"style"'), isFalse,
          reason: 'Default style should not be encoded: $json');
      expect(json.contains('"maxLines"'), isFalse,
          reason: 'Null maxLines should not be encoded: $json');
    });

    test('roundTripImg', () {
      assertRoundTrip(
          const AmeImg(url: 'https://example.com/photo.jpg', height: 180));
    });

    test('roundTripImgNoHeight', () {
      assertRoundTrip(const AmeImg(url: 'https://example.com/photo.jpg'));
    });

    test('roundTripIcon', () {
      assertRoundTrip(const AmeIcon(name: 'partly_cloudy_day', size: 28));
    });

    test('roundTripIconDefaults', () {
      assertRoundTrip(const AmeIcon(name: 'star'));
    });

    test('roundTripDivider', () {
      const node = AmeDivider();
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json, equals('{"_type":"divider"}'));
    });

    test('roundTripSpacer', () {
      assertRoundTrip(const AmeSpacer(height: 16));
    });

    test('roundTripSpacerDefaults', () {
      assertRoundTrip(const AmeSpacer());
    });
  });

  // ── Semantic Primitives ────────────────────────────────────────────

  group('Semantic Primitives', () {
    test('roundTripCard', () {
      assertRoundTrip(const AmeCard(
        children: [
          AmeTxt(text: 'Title', style: TxtStyle.title),
          AmeTxt(text: 'Description'),
        ],
        elevation: 2,
      ));
    });

    test('roundTripBadge', () {
      assertRoundTrip(const AmeBadge(label: '\u2605 4.5', variant: BadgeVariant.info));
    });

    test('roundTripBadgeDefaults', () {
      assertRoundTrip(const AmeBadge(label: 'Tag'));
    });

    test('roundTripProgress', () {
      assertRoundTrip(const AmeProgress(value: 0.67, label: '67% complete'));
    });

    test('roundTripProgressNoLabel', () {
      assertRoundTrip(const AmeProgress(value: 0.3));
    });
  });

  // ── Interactive Primitives ─────────────────────────────────────────

  group('Interactive Primitives', () {
    test('roundTripBtnWithToolAction', () {
      assertRoundTrip(const AmeBtn(
        label: 'Save',
        action: AmeCallTool(name: 'add_note', args: {'title': 'Meeting Notes'}),
        style: BtnStyle.primary,
      ));
    });

    test('roundTripBtnWithUriAction', () {
      assertRoundTrip(const AmeBtn(
        label: 'Directions',
        action: AmeOpenUri(uri: "geo:40.72,-73.99?q=Luigi's"),
        style: BtnStyle.text,
      ));
    });

    test('roundTripBtnWithNavAction', () {
      assertRoundTrip(const AmeBtn(
        label: 'Home',
        action: AmeNavigate(route: 'home'),
        style: BtnStyle.outline,
      ));
    });

    test('roundTripBtnWithCopyAction', () {
      assertRoundTrip(const AmeBtn(
        label: 'Copy Address',
        action: AmeCopyText(text: '119 Mulberry St'),
        style: BtnStyle.text,
      ));
    });

    test('roundTripBtnWithSubmitAction', () {
      assertRoundTrip(const AmeBtn(
        label: 'Confirm',
        action: AmeSubmit(
          toolName: 'create_reservation',
          staticArgs: {'restaurant': "Luigi's"},
        ),
        style: BtnStyle.primary,
      ));
    });

    test('roundTripBtnWithIcon', () {
      assertRoundTrip(const AmeBtn(
        label: 'Call',
        action: AmeOpenUri(uri: 'tel:+15551234567'),
        style: BtnStyle.primary,
        icon: 'phone',
      ));
    });

    test('roundTripInput', () {
      assertRoundTrip(
          const AmeInput(id: 'email', label: 'Email Address', type: InputType.email));
    });

    test('roundTripInputSelect', () {
      assertRoundTrip(const AmeInput(
        id: 'guests',
        label: 'Number of Guests',
        type: InputType.select,
        options: ['1', '2', '3', '4', '5', '6'],
      ));
    });

    test('roundTripInputDefaults', () {
      assertRoundTrip(const AmeInput(id: 'name', label: 'Your Name'));
    });

    test('roundTripToggle', () {
      assertRoundTrip(const AmeToggle(
          id: 'notifications', label: 'Enable notifications', defaultValue: true));
    });

    test('roundTripToggleDefaults', () {
      const node = AmeToggle(id: 'agree', label: 'I agree to the terms');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"default"'), isFalse,
          reason: 'Default false should not be encoded: $json');
    });
  });

  // ── Data Primitives ────────────────────────────────────────────────

  group('Data Primitives', () {
    test('roundTripDataList', () {
      assertRoundTrip(const AmeDataList(
        children: [AmeTxt(text: 'Item 1'), AmeTxt(text: 'Item 2'), AmeTxt(text: 'Item 3')],
        dividers: true,
      ));
    });

    test('roundTripDataListNoDividers', () {
      assertRoundTrip(const AmeDataList(
        children: [AmeTxt(text: 'A'), AmeTxt(text: 'B')],
        dividers: false,
      ));
    });

    test('roundTripTable', () {
      assertRoundTrip(const AmeTable(
        headers: ['Feature', 'Basic', 'Pro'],
        rows: [
          ['Storage', '50 GB', '500 GB'],
          ['Users', '1', '10'],
          ['Support', 'Email', '24/7'],
        ],
      ));
    });
  });

  // ── Structural Types ───────────────────────────────────────────────

  group('Structural Types', () {
    test('roundTripRef', () {
      assertRoundTrip(const AmeRef(id: 'header'));
    });

    test('roundTripEach', () {
      assertRoundTrip(
          const AmeEach(dataPath: 'places', templateId: 'place_tpl'));
    });
  });

  // ── Action Round-Trip Tests ────────────────────────────────────────

  group('Action Round-Trips', () {
    test('roundTripCallToolAction', () {
      assertActionRoundTrip(const AmeCallTool(
        name: 'create_calendar_event',
        args: {'title': "Dinner at Luigi's", 'date': '2026-04-15'},
      ));
    });

    test('roundTripCallToolWithInputRef', () {
      const action = AmeCallTool(
        name: 'send_message',
        args: {
          'to': r'${input.recipient}',
          'body': r'${input.body}',
        },
      );
      assertActionRoundTrip(action);
      final json = AmeSerializer.actionToJson(action);
      expect(json.contains(r'${input.recipient}'), isTrue,
          reason: 'Input ref must survive as literal: $json');
    });

    test('roundTripOpenUriAction', () {
      assertActionRoundTrip(
          const AmeOpenUri(uri: "geo:40.72,-73.99?q=Luigi's"));
    });

    test('roundTripNavigateAction', () {
      assertActionRoundTrip(const AmeNavigate(route: 'calendar'));
    });

    test('roundTripCopyTextAction', () {
      assertActionRoundTrip(
          const AmeCopyText(text: '119 Mulberry St, New York'));
    });

    test('roundTripSubmitAction', () {
      assertActionRoundTrip(const AmeSubmit(
        toolName: 'create_reservation',
        staticArgs: {'restaurant': "Luigi's"},
      ));
    });

    test('roundTripSubmitActionEmpty', () {
      assertActionRoundTrip(const AmeSubmit(toolName: 'save_draft'));
    });
  });

  // ── Complex Tree ───────────────────────────────────────────────────

  group('Complex Trees', () {
    test('roundTripWeatherCardTree', () {
      const tree = AmeCard(children: [
        AmeRow(children: [
          AmeTxt(text: 'San Francisco', style: TxtStyle.title),
          AmeIcon(name: 'partly_cloudy_day', size: 28),
        ], align: Align.spaceBetween),
        AmeTxt(text: '62\u00b0', style: TxtStyle.display),
        AmeTxt(text: 'Partly Cloudy'),
        AmeRow(children: [
          AmeTxt(text: 'H:68\u00b0  L:55\u00b0', style: TxtStyle.caption),
          AmeTxt(text: 'Humidity: 72%', style: TxtStyle.caption),
        ], align: Align.spaceBetween),
      ]);
      assertRoundTrip(tree);
      final json = AmeSerializer.toJson(tree);
      expect(json.contains('"San Francisco"'), isTrue);
      expect(json.contains('"partly_cloudy_day"'), isTrue);
    });

    test('weatherCardJsonIsCompact', () {
      const tree = AmeCard(children: [
        AmeTxt(text: '62\u00b0', style: TxtStyle.display),
        AmeTxt(text: 'Partly Cloudy'),
      ]);
      final json = AmeSerializer.toJson(tree);
      expect(json.contains('"elevation"'), isFalse,
          reason: 'Default elevation should not be in JSON');
    });

    test('roundTripDeeplyNestedTree', () {
      const tree = AmeCol(children: [
        AmeCard(children: [
          AmeRow(children: [
            AmeTxt(text: 'Name', style: TxtStyle.title),
            AmeBadge(label: '\u2605 4.5', variant: BadgeVariant.info),
          ], align: Align.spaceBetween),
          AmeTxt(text: '123 Main St', style: TxtStyle.caption),
          AmeRow(children: [
            AmeBtn(
              label: 'Schedule',
              action: AmeCallTool(name: 'create_event', args: {'title': 'Dinner'}),
              style: BtnStyle.primary,
            ),
            AmeBtn(
              label: 'Directions',
              action: AmeOpenUri(uri: 'geo:40.72,-73.99'),
              style: BtnStyle.text,
            ),
          ]),
        ]),
      ]);
      assertRoundTrip(tree);
    });

    test('roundTripTreeWithRefs', () {
      const tree = AmeCol(children: [
        AmeRef(id: 'header'),
        AmeRef(id: 'body'),
        AmeRef(id: 'footer'),
      ]);
      assertRoundTrip(tree);
      final json = AmeSerializer.toJson(tree);
      expect(json.contains('"_type":"ref"'), isTrue);
    });

    test('roundTripTreeWithEach', () {
      assertRoundTrip(const AmeCol(children: [
        AmeTxt(text: 'Nearby Places', style: TxtStyle.headline),
        AmeEach(dataPath: 'places', templateId: 'place_tpl'),
      ]));
    });
  });

  // ── encodeDefaults=false ───────────────────────────────────────────

  group('Default Omission', () {
    test('encodeDefaultsFalseOmitsDefaults', () {
      final json = AmeSerializer.toJson(const AmeTxt(text: 'Hello'));
      expect(json, equals('{"_type":"txt","text":"Hello"}'));
    });

    test('encodeDefaultsFalseIncludesNonDefaults', () {
      final json = AmeSerializer.toJson(
          const AmeTxt(text: 'Hello', style: TxtStyle.headline));
      expect(json.contains('"style":"headline"'), isTrue,
          reason: 'Non-default style must be encoded: $json');
    });

    test('typeDiscriminatorUsesSerialName', () {
      final json = AmeSerializer.toJson(
          const AmeBadge(label: 'New', variant: BadgeVariant.success));
      expect(json.startsWith('{"_type":"badge"'), isTrue,
          reason: 'Type discriminator must use correct name: $json');
    });

    test('dividerTypeDiscriminator', () {
      final json = AmeSerializer.toJson(const AmeDivider());
      expect(json.contains('"_type":"divider"'), isTrue);
    });
  });

  // ── v1.1 Round-Trips ──────────────────────────────────────────────

  group('v1.1 Chart', () {
    test('roundTripChart', () {
      assertRoundTrip(const AmeChart(
        type: ChartType.line,
        values: [1.0, 2.5, 3.0],
        labels: ['Jan', 'Feb', 'Mar'],
        series: [
          [1.0, 2.0],
          [3.0, 4.0],
        ],
        height: 180,
        color: SemanticColor.primary,
      ));
    });

    test('roundTripChartDefaults', () {
      const node = AmeChart(type: ChartType.bar);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"height"'), isFalse,
          reason: 'Default height=200 must be omitted: $json');
      expect(json.contains('"values"'), isFalse,
          reason: 'Null values must be omitted: $json');
      expect(json.contains('"color"'), isFalse,
          reason: 'Null color must be omitted: $json');
    });
  });

  group('v1.1 Code', () {
    test('roundTripCode', () {
      assertRoundTrip(const AmeCode(
        language: 'kotlin',
        content: 'fun main() = println("hello")',
        title: 'Main.kt',
      ));
    });

    test('roundTripCodeDefaults', () {
      const node = AmeCode(language: 'text', content: 'hello');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"title"'), isFalse,
          reason: 'Null title must be omitted: $json');
    });
  });

  group('v1.1 Accordion', () {
    test('roundTripAccordion', () {
      assertRoundTrip(const AmeAccordion(
        title: 'Details',
        children: [AmeTxt(text: 'Content')],
        expanded: true,
      ));
    });

    test('roundTripAccordionDefaults', () {
      const node = AmeAccordion(title: 'FAQ');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"expanded"'), isFalse,
          reason: 'Default expanded=false must be omitted: $json');
    });
  });

  group('v1.1 Carousel', () {
    test('roundTripCarousel', () {
      assertRoundTrip(const AmeCarousel(
        children: [AmeTxt(text: 'A'), AmeTxt(text: 'B')],
        peek: 32,
      ));
    });

    test('roundTripCarouselDefaults', () {
      const node = AmeCarousel();
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"peek"'), isFalse,
          reason: 'Default peek=24 must be omitted: $json');
    });
  });

  group('v1.1 Callout', () {
    test('roundTripCallout', () {
      assertRoundTrip(const AmeCallout(
        type: CalloutType.warning,
        content: 'Be careful',
        title: 'Warning',
      ));
    });

    test('roundTripCalloutDefaults', () {
      const node = AmeCallout(type: CalloutType.info, content: 'Note');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"title"'), isFalse,
          reason: 'Null title must be omitted: $json');
    });
  });

  group('v1.1 Timeline', () {
    test('roundTripTimeline', () {
      assertRoundTrip(const AmeTimeline(children: [
        AmeTimelineItem(title: 'Step 1', subtitle: 'Done', status: TimelineStatus.done),
        AmeTimelineItem(title: 'Step 2', status: TimelineStatus.active),
      ]));
    });

    test('roundTripTimelineItem', () {
      assertRoundTrip(const AmeTimelineItem(
        title: 'Shipped',
        subtitle: 'Package in transit',
        status: TimelineStatus.done,
      ));
    });

    test('roundTripTimelineItemDefaults', () {
      const node = AmeTimelineItem(title: 'Pending step');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"status"'), isFalse,
          reason: 'Default status=pending must be omitted: $json');
      expect(json.contains('"subtitle"'), isFalse,
          reason: 'Null subtitle must be omitted: $json');
    });
  });

  group('v1.1 Semantic Color', () {
    test('roundTripTxtWithColor', () {
      const node = AmeTxt(text: 'Alert', color: SemanticColor.error);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"color":"error"'), isTrue,
          reason: 'Color must be serialized: $json');
    });

    test('roundTripTxtWithoutColor', () {
      const node = AmeTxt(text: 'Normal', style: TxtStyle.body);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"color"'), isFalse,
          reason: 'Null color must be omitted: $json');
    });

    test('roundTripBadgeWithColor', () {
      const node = AmeBadge(
        label: 'Live',
        variant: BadgeVariant.success,
        color: SemanticColor.success,
      );
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"color":"success"'), isTrue,
          reason: 'Color must be serialized: $json');
    });
  });

  group('v1.1 Enum Round-Trips', () {
    test('roundTripChartType', () {
      for (final ct in ChartType.values) {
        assertRoundTrip(AmeChart(type: ct));
      }
    });

    test('roundTripCalloutType', () {
      for (final ct in CalloutType.values) {
        assertRoundTrip(AmeCallout(type: ct, content: 'test'));
      }
    });

    test('roundTripTimelineStatus', () {
      for (final ts in TimelineStatus.values) {
        assertRoundTrip(AmeTimelineItem(title: 'test', status: ts));
      }
    });

    test('roundTripSemanticColor', () {
      for (final sc in SemanticColor.values) {
        assertRoundTrip(AmeTxt(text: 'test', color: sc));
      }
    });
  });

  group('v1.1 Complex Tree', () {
    test('roundTripTreeWithNewPrimitives', () {
      assertRoundTrip(const AmeCol(children: [
        AmeCallout(type: CalloutType.tip, content: 'Hint', title: 'Pro Tip'),
        AmeAccordion(
          title: 'Details',
          children: [
            AmeCode(language: 'json', content: '{"key":"val"}'),
            AmeChart(type: ChartType.sparkline, values: [1.0, 3.0, 2.0]),
          ],
          expanded: true,
        ),
        AmeCarousel(children: [
          AmeCard(children: [AmeTxt(text: 'Slide 1')]),
          AmeCard(children: [AmeTxt(text: 'Slide 2')]),
        ], peek: 40),
        AmeTimeline(children: [
          AmeTimelineItem(title: 'Ordered', subtitle: 'April 1', status: TimelineStatus.done),
          AmeTimelineItem(title: 'Shipped', status: TimelineStatus.active),
          AmeTimelineItem(title: 'Delivered', status: TimelineStatus.pending),
        ]),
      ]));
    });
  });

  // ── v1.4 Row weights / crossAlign ──────────────────────────────────

  group('v1.4 Row Layout Extensions', () {
    test('roundTripRowWithWeights', () {
      assertRoundTrip(const AmeRow(
        children: [AmeTxt(text: 'Wide'), AmeTxt(text: 'Narrow')],
        weights: [1, 0],
      ));
    });

    test('roundTripRowWithCrossAlign', () {
      assertRoundTrip(const AmeRow(
        children: [AmeTxt(text: 'A'), AmeTxt(text: 'B')],
        crossAlign: Align.top,
      ));
    });

    test('roundTripRowWithWeightsAndCrossAlign', () {
      assertRoundTrip(const AmeRow(
        children: [AmeTxt(text: 'A'), AmeTxt(text: 'B')],
        align: Align.spaceBetween,
        gap: 12,
        weights: [1, 1],
        crossAlign: Align.bottom,
      ));
    });

    test('roundTripRowDefaultsOmitsNewFields', () {
      // v1.3 conformance preservation: a Row with only children must serialize
      // byte-identically to v1.3 output (no weights, no cross_align).
      const node = AmeRow(children: [AmeTxt(text: 'Item')]);
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('weights'), isFalse,
          reason: 'Default weights must not be encoded: $json');
      expect(json.contains('cross_align'), isFalse,
          reason: 'Default cross_align must not be encoded: $json');
    });

    test('rowCrossAlignSerializesAsSnakeCase', () {
      const node = AmeRow(
        children: [AmeTxt(text: 'A')],
        crossAlign: Align.top,
      );
      final json = AmeSerializer.toJson(node);
      expect(json.contains('"cross_align"'), isTrue,
          reason: 'crossAlign must serialize as snake_case: $json');
      expect(json.contains('"crossAlign"'), isFalse,
          reason: 'camelCase must not appear in JSON: $json');
    });

    test('roundTripAlignTopBottom', () {
      // v1.4 added Align.top and Align.bottom; verify both via Row.crossAlign.
      for (final align in [Align.top, Align.bottom]) {
        assertRoundTrip(AmeRow(
          children: const [AmeTxt(text: 'X')],
          crossAlign: align,
        ));
      }
    });
  });

  // ── v1.4 list_item primitive ───────────────────────────────────────

  group('v1.4 list_item', () {
    test('roundTripListItemFull', () {
      assertRoundTrip(const AmeListItem(
        title: 'Pizza Place',
        subtitle: '71 Mulberry St',
        leading: AmeIcon(name: 'restaurant'),
        trailing: AmeBadge(label: '4.5', variant: BadgeVariant.info),
        action: AmeNavigate(route: '/detail'),
      ));
    });

    test('roundTripListItemMinimal', () {
      const node = AmeListItem(title: 'Title only');
      assertRoundTrip(node);
      final json = AmeSerializer.toJson(node);
      expect(json.contains('subtitle'), isFalse,
          reason: 'Default subtitle must not be encoded: $json');
      expect(json.contains('leading'), isFalse,
          reason: 'Default leading must not be encoded: $json');
      expect(json.contains('trailing'), isFalse,
          reason: 'Default trailing must not be encoded: $json');
      expect(json.contains('"action"'), isFalse,
          reason: 'Default action must not be encoded: $json');
    });

    test('roundTripListItemNestedClickTargetCase', () {
      // The NORMATIVE nested click target case (§list_item): row-level action
      // PLUS a trailing AmeBtn with its own action. Both must survive round-trip.
      assertRoundTrip(const AmeListItem(
        title: 'Pizza Place',
        subtitle: '71 Mulberry St',
        leading: AmeIcon(name: 'restaurant'),
        trailing: AmeBtn(
          label: 'Directions',
          action: AmeNavigate(route: '/dir'),
        ),
        action: AmeNavigate(route: '/detail'),
      ));
    });
  });
}
