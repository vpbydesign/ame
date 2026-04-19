import 'package:test/test.dart';
import 'package:ame_flutter/ame_flutter.dart';

void main() {
  AmeNode? parse(String input) {
    final parser = AmeParser();
    return parser.parse(input);
  }

  AmeParser parserFor(String input) {
    final parser = AmeParser();
    parser.parse(input);
    return parser;
  }

  // ════════════════════════════════════════════════════════════════════
  // Happy Path — All 15 v1.0 Primitives
  // ════════════════════════════════════════════════════════════════════

  group('v1.0 primitives', () {
    test('parseCol', () {
      final result = parse('root = col([a, b])\na = txt("Hello")\nb = txt("World")');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children.length, 2);
      expect(col.align, Align.start);
      expect((col.children[0] as AmeTxt).text, 'Hello');
    });

    test('parseColWithAlign', () {
      final result = parse('root = col([a], center)\na = txt("Centered")');
      expect(result, isA<AmeCol>());
      expect((result as AmeCol).align, Align.center);
    });

    test('parseRow', () {
      final result = parse(
          'root = row([a, b], space_between)\na = txt("Left")\nb = txt("Right")');
      expect(result, isA<AmeRow>());
      final row = result as AmeRow;
      expect(row.children.length, 2);
      expect(row.align, Align.spaceBetween);
      expect(row.gap, 8);
    });

    test('parseRowWithGap', () {
      final result = parse('root = row([a, b], 12)\na = txt("A")\nb = txt("B")');
      expect(result, isA<AmeRow>());
      final row = result as AmeRow;
      expect(row.gap, 12);
      expect(row.align, Align.start);
    });

    test('parseRowWithAlignAndGap', () {
      final result =
          parse('root = row([a, b], space_between, 16)\na = txt("A")\nb = txt("B")');
      expect(result, isA<AmeRow>());
      final row = result as AmeRow;
      expect(row.align, Align.spaceBetween);
      expect(row.gap, 16);
    });

    test('parseTxt', () {
      final result = parse('root = txt("Hello World", headline)');
      expect(result, isA<AmeTxt>());
      final txt = result as AmeTxt;
      expect(txt.text, 'Hello World');
      expect(txt.style, TxtStyle.headline);
    });

    test('parseTxtDefaults', () {
      final result = parse('root = txt("Simple text")');
      expect(result, isA<AmeTxt>());
      final txt = result as AmeTxt;
      expect(txt.text, 'Simple text');
      expect(txt.style, TxtStyle.body);
      expect(txt.maxLines, isNull);
    });

    test('parseTxtWithMaxLines', () {
      final result = parse('root = txt("Long text", body, max_lines=3)');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).maxLines, 3);
    });

    test('parseTxtWithEscapes', () {
      final result = parse('root = txt("She said \\"hello\\"")');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).text, 'She said "hello"');
    });

    test('parseImg', () {
      final result = parse('root = img("https://example.com/photo.jpg", 180)');
      expect(result, isA<AmeImg>());
      final img = result as AmeImg;
      expect(img.url, 'https://example.com/photo.jpg');
      expect(img.height, 180);
    });

    test('parseImgNoHeight', () {
      final result = parse('root = img("https://example.com/photo.jpg")');
      expect(result, isA<AmeImg>());
      expect((result as AmeImg).height, isNull);
    });

    test('parseIcon', () {
      final result = parse('root = icon("partly_cloudy_day", 28)');
      expect(result, isA<AmeIcon>());
      final icon = result as AmeIcon;
      expect(icon.name, 'partly_cloudy_day');
      expect(icon.size, 28);
    });

    test('parseIconDefaults', () {
      final result = parse('root = icon("star")');
      expect(result, isA<AmeIcon>());
      expect((result as AmeIcon).size, 20);
    });

    test('parseDivider', () {
      final result = parse('root = divider()');
      expect(result, isA<AmeDivider>());
    });

    test('parseSpacer', () {
      final result = parse('root = spacer(16)');
      expect(result, isA<AmeSpacer>());
      expect((result as AmeSpacer).height, 16);
    });

    test('parseSpacerDefaults', () {
      final result = parse('root = spacer()');
      expect(result, isA<AmeSpacer>());
      expect((result as AmeSpacer).height, 8);
    });

    test('parseCard', () {
      final result =
          parse('root = card([title, body])\ntitle = txt("Title", title)\nbody = txt("Body text")');
      expect(result, isA<AmeCard>());
      final card = result as AmeCard;
      expect(card.children.length, 2);
      expect(card.elevation, 1);
    });

    test('parseCardWithElevation', () {
      final result = parse('root = card([a], 0)\na = txt("Flat")');
      expect(result, isA<AmeCard>());
      expect((result as AmeCard).elevation, 0);
    });

    test('parseBadge', () {
      final result = parse('root = badge("\u2605 4.5", info)');
      expect(result, isA<AmeBadge>());
      final badge = result as AmeBadge;
      expect(badge.label, '\u2605 4.5');
      expect(badge.variant, BadgeVariant.info);
    });

    test('parseBadgeDefaults', () {
      final result = parse('root = badge("Tag")');
      expect(result, isA<AmeBadge>());
      expect((result as AmeBadge).variant, BadgeVariant.defaultVariant);
    });

    test('parseProgress', () {
      final result = parse('root = progress(0.67, "67% complete")');
      expect(result, isA<AmeProgress>());
      final p = result as AmeProgress;
      expect(p.value, closeTo(0.67, 0.01));
      expect(p.label, '67% complete');
    });

    test('parseProgressNoLabel', () {
      final result = parse('root = progress(0.3)');
      expect(result, isA<AmeProgress>());
      expect((result as AmeProgress).label, isNull);
    });

    test('parseInput', () {
      final result = parse('root = input("email", "Email Address", email)');
      expect(result, isA<AmeInput>());
      final input = result as AmeInput;
      expect(input.id, 'email');
      expect(input.label, 'Email Address');
      expect(input.type, InputType.email);
    });

    test('parseInputDefaults', () {
      final result = parse('root = input("name", "Your Name")');
      expect(result, isA<AmeInput>());
      expect((result as AmeInput).type, InputType.text);
    });

    test('parseInputSelect', () {
      final result = parse(
          'root = input("guests", "Number of Guests", select, options=["1","2","3","4"])');
      expect(result, isA<AmeInput>());
      final input = result as AmeInput;
      expect(input.type, InputType.select);
      expect(input.options, ['1', '2', '3', '4']);
    });

    test('parseToggle', () {
      final result = parse('root = toggle("agree", "I agree to the terms")');
      expect(result, isA<AmeToggle>());
      final toggle = result as AmeToggle;
      expect(toggle.id, 'agree');
      expect(toggle.defaultValue, false);
    });

    test('parseToggleWithDefault', () {
      final result =
          parse('root = toggle("notifications", "Enable notifications", true)');
      expect(result, isA<AmeToggle>());
      expect((result as AmeToggle).defaultValue, true);
    });

    test('parseList', () {
      final result = parse(
          'root = list([a, b, c])\na = txt("Item 1")\nb = txt("Item 2")\nc = txt("Item 3")');
      expect(result, isA<AmeDataList>());
      final list = result as AmeDataList;
      expect(list.children.length, 3);
      expect(list.dividers, true);
    });

    test('parseListNoDividers', () {
      final result = parse('root = list([a], false)\na = txt("Solo")');
      expect(result, isA<AmeDataList>());
      expect((result as AmeDataList).dividers, false);
    });

    test('parseTable', () {
      final result = parse(
          'root = table(["Feature", "Basic", "Pro"], [["Storage", "50 GB", "500 GB"], ["Users", "1", "10"]])');
      expect(result, isA<AmeTable>());
      final table = result as AmeTable;
      expect(table.headers, ['Feature', 'Basic', 'Pro']);
      expect(table.rows.length, 2);
      expect(table.rows[0], ['Storage', '50 GB', '500 GB']);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Button with All 5 Action Types
  // ════════════════════════════════════════════════════════════════════

  group('Button actions', () {
    test('parseBtnWithToolAction', () {
      final result = parse(
          'root = btn("Save", tool(add_note, title="Meeting Notes"), primary)');
      expect(result, isA<AmeBtn>());
      final btn = result as AmeBtn;
      expect(btn.label, 'Save');
      expect(btn.style, BtnStyle.primary);
      expect(btn.action, isA<AmeCallTool>());
      final action = btn.action as AmeCallTool;
      expect(action.name, 'add_note');
      expect(action.args['title'], 'Meeting Notes');
    });

    test('parseBtnWithUriAction', () {
      final result = parse(
          'root = btn("Directions", uri("geo:40.72,-73.99?q=Luigi\'s"), text)');
      expect(result, isA<AmeBtn>());
      final btn = result as AmeBtn;
      expect(btn.style, BtnStyle.text);
      expect(btn.action, isA<AmeOpenUri>());
      expect((btn.action as AmeOpenUri).uri, "geo:40.72,-73.99?q=Luigi's");
    });

    test('parseBtnWithNavAction', () {
      final result = parse('root = btn("Home", nav("home"), outline)');
      expect(result, isA<AmeBtn>());
      final btn = result as AmeBtn;
      expect(btn.style, BtnStyle.outline);
      expect((btn.action as AmeNavigate).route, 'home');
    });

    test('parseBtnWithCopyAction', () {
      final result =
          parse('root = btn("Copy Address", copy("119 Mulberry St"), text)');
      expect(result, isA<AmeBtn>());
      expect((result as AmeBtn).action, isA<AmeCopyText>());
      expect(((result).action as AmeCopyText).text, '119 Mulberry St');
    });

    test('parseBtnWithSubmitAction', () {
      final result = parse(
          'root = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi\'s"), primary)');
      expect(result, isA<AmeBtn>());
      final action = (result as AmeBtn).action;
      expect(action, isA<AmeSubmit>());
      final submit = action as AmeSubmit;
      expect(submit.toolName, 'create_reservation');
      expect(submit.staticArgs['restaurant'], "Luigi's");
    });

    test('parseBtnWithIcon', () {
      final result =
          parse('root = btn("Call", uri("tel:+15551234567"), primary, icon="phone")');
      expect(result, isA<AmeBtn>());
      expect((result as AmeBtn).icon, 'phone');
    });

    test('parseBtnDefaultStyle', () {
      final result = parse('root = btn("Click", nav("home"))');
      expect(result, isA<AmeBtn>());
      expect((result as AmeBtn).style, BtnStyle.primary);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Forward References
  // ════════════════════════════════════════════════════════════════════

  group('Forward references', () {
    test('parseForwardRefChildBeforeParent', () {
      final result = parse(
          'root = col([header, body])\nheader = txt("Title", title)\nbody = card([content])\ncontent = txt("Details", body)');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children.length, 2);
      expect((col.children[0] as AmeTxt).text, 'Title');
      final card = col.children[1] as AmeCard;
      expect((card.children[0] as AmeTxt).text, 'Details');
    });

    test('streamingModeProducesRefs', () {
      final parser = AmeParser();
      final rootResult = parser.parseLine('root = col([header, body])');
      expect(rootResult, isNotNull);
      expect(rootResult!.$1, 'root');
      final rootNode = rootResult.$2 as AmeCol;
      expect(rootNode.children.every((c) => c is AmeRef), isTrue);

      parser.parseLine('header = txt("Title", title)');
      final tree = parser.getResolvedTree();
      expect(tree, isA<AmeCol>());
      final resolved = tree as AmeCol;
      expect(resolved.children[0], isA<AmeTxt>());
      expect(resolved.children[1], isA<AmeRef>());
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Data Binding
  // ════════════════════════════════════════════════════════════════════

  group('Data binding', () {
    test('parseDataRefTopLevel', () {
      final result = parse('root = txt(\$name, title)');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).text, '\$name');
      expect(result.style, TxtStyle.title);
    });

    test('parseDataRefNested', () {
      final result = parse('root = txt(\$address/city, caption)');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).text, '\$address/city');
    });

    test('parseDataSection', () {
      final parser = parserFor(
          'root = col([name_label, rating_label])\nname_label = txt(\$name, title)\nrating_label = badge(\$rating, info)\n---\n{"name": "Luigi\'s", "rating": "\u2605 4.5"}');
      expect(parser.getDataModel(), isNotNull);
      expect(parser.resolveDataPath('name'), "Luigi's");
      expect(parser.resolveDataPath('rating'), '\u2605 4.5');
    });

    test('parseDataSectionNestedPath', () {
      final parser = parserFor(
          'root = txt(\$address/city, caption)\n---\n{"address": {"city": "New York", "state": "NY"}}');
      expect(parser.resolveDataPath('address/city'), 'New York');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // each() Construct
  // ════════════════════════════════════════════════════════════════════

  group('each()', () {
    test('parseEach', () {
      final result = parse(
          'root = col([title, results])\ntitle = txt("Italian Restaurants", headline)\nresults = each(\$places, place_tpl)\nplace_tpl = card([txt(\$name, title)])');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      final eachNode = col.children[1];
      expect(eachNode, isA<AmeEach>());
      expect((eachNode as AmeEach).dataPath, 'places');
      expect(eachNode.templateId, 'place_tpl');
    });

    test('eachExpandsWithDataSection', () {
      final result = parse(
          'root = col([header, results])\nheader = txt("Restaurants", headline)\nresults = each(\$places, place_tpl)\nplace_tpl = card([txt(\$name, title)])\n---\n{"places":[{"name":"Pizza Palace"},{"name":"Sushi Spot"},{"name":"Taco Town"}]}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children.length, 2);
      final expanded = col.children[1] as AmeCol;
      expect(expanded.children.length, 3);
      expect(((expanded.children[0] as AmeCard).children[0] as AmeTxt).text,
          'Pizza Palace');
      expect(((expanded.children[2] as AmeCard).children[0] as AmeTxt).text,
          'Taco Town');
    });

    test('eachPreservedWithoutDataSection', () {
      final result = parse(
          'root = col([title, results])\ntitle = txt("Restaurants", headline)\nresults = each(\$places, place_tpl)\nplace_tpl = card([txt(\$name, title)])');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children[1], isA<AmeEach>());
    });

    test('eachEmptyArrayProducesEmptyCol', () {
      final result = parse(
          'root = col([header, results])\nheader = txt("Results", headline)\nresults = each(\$items, item_tpl)\nitem_tpl = txt(\$label, body)\n---\n{"items":[]}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      final expanded = col.children[1];
      expect(expanded, isA<AmeCol>());
      expect((expanded as AmeCol).children.length, 0);
    });

    test('eachSingleElementReturnsUnwrapped', () {
      final result = parse(
          'root = col([header, results])\nheader = txt("Solo", headline)\nresults = each(\$items, item_tpl)\nitem_tpl = txt(\$value, body)\n---\n{"items":[{"value":"Only One"}]}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      final expanded = col.children[1];
      expect(expanded, isA<AmeTxt>());
      expect((expanded as AmeTxt).text, 'Only One');
    });

    test('eachResolvesMultiplePathsInTemplate', () {
      final result = parse(
          'root = each(\$contacts, contact_card)\ncontact_card = row([txt(\$name, title), txt(\$phone, body)])\n---\n{"contacts":[{"name":"Alice","phone":"555-1234"},{"name":"Bob","phone":"555-5678"}]}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children.length, 2);
      final row0 = col.children[0] as AmeRow;
      expect((row0.children[0] as AmeTxt).text, 'Alice');
      expect((row0.children[1] as AmeTxt).text, '555-1234');
    });

    test('eachMissingPathProducesEmptyCol', () {
      final parser = AmeParser();
      final result = parser.parse(
          'root = col([header, results])\nheader = txt("Missing", headline)\nresults = each(\$nonexistent, item_tpl)\nitem_tpl = txt(\$value, body)\n---\n{"other_key":"hello"}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      final expanded = col.children[1] as AmeCol;
      expect(expanded.children.length, 0);
      expect(parser.warnings.isNotEmpty, isTrue);
    });

    test('eachNestedPathResolvesCorrectly', () {
      final result = parse(
          'root = each(\$data/results, item_tpl)\nitem_tpl = txt(\$title, body)\n---\n{"data":{"results":[{"title":"First"},{"title":"Second"}]}}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      expect(col.children.length, 2);
      expect((col.children[0] as AmeTxt).text, 'First');
      expect((col.children[1] as AmeTxt).text, 'Second');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Complete Examples from syntax.md
  // ════════════════════════════════════════════════════════════════════

  group('Complete examples', () {
    test('parseWeatherCard', () {
      final result = parse(
          'root = card([weather_header, temp, condition, details])\n'
          'weather_header = row([city, weather_icon], space_between)\n'
          'city = txt("San Francisco", title)\n'
          'weather_icon = icon("partly_cloudy_day", 28)\n'
          'temp = txt("62\u00b0", display)\n'
          'condition = txt("Partly Cloudy", body)\n'
          'details = row([high_low, humidity], space_between)\n'
          'high_low = txt("H:68\u00b0  L:55\u00b0", caption)\n'
          'humidity = txt("Humidity: 72%", caption)');
      expect(result, isA<AmeCard>());
      final card = result as AmeCard;
      expect(card.children.length, 4);

      final header = card.children[0] as AmeRow;
      expect(header.align, Align.spaceBetween);
      expect((header.children[0] as AmeTxt).text, 'San Francisco');
      expect((header.children[1] as AmeIcon).name, 'partly_cloudy_day');

      expect((card.children[1] as AmeTxt).text, '62\u00b0');
      expect((card.children[1] as AmeTxt).style, TxtStyle.display);
    });

    test('parseBookingForm', () {
      final result = parse(
          'root = card([form_title, form_fields, form_actions])\n'
          'form_title = txt("Book a Table", headline)\n'
          'form_fields = col([date_field, time_field, guests_field, notes_field])\n'
          'date_field = input("date", "Date", date)\n'
          'time_field = input("time", "Time", time)\n'
          'guests_field = input("guests", "Number of Guests", select, options=["1","2","3","4","5","6","7","8"])\n'
          'notes_field = input("notes", "Special Requests", text)\n'
          'form_actions = row([cancel_btn, confirm_btn], space_between)\n'
          'cancel_btn = btn("Cancel", nav("home"), text)\n'
          'confirm_btn = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi\'s"), primary)');
      expect(result, isA<AmeCard>());
      final card = result as AmeCard;
      expect(card.children.length, 3);

      final fields = card.children[1] as AmeCol;
      expect(fields.children.length, 4);
      expect((fields.children[0] as AmeInput).type, InputType.date);

      final guests = fields.children[2] as AmeInput;
      expect(guests.type, InputType.select);
      expect(guests.options!.length, 8);

      final actions = card.children[2] as AmeRow;
      expect(actions.align, Align.spaceBetween);
      final confirmBtn = actions.children[1] as AmeBtn;
      expect((confirmBtn.action as AmeSubmit).toolName, 'create_reservation');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Inline Component Calls
  // ════════════════════════════════════════════════════════════════════

  group('Inline components', () {
    test('parseInlineComponentCallsInArray', () {
      final result = parse(
          'root = row([txt("Name", title), badge("\u2605 4.5", info)], space_between)');
      expect(result, isA<AmeRow>());
      final row = result as AmeRow;
      expect(row.children.length, 2);
      expect((row.children[0] as AmeTxt).text, 'Name');
      expect((row.children[1] as AmeBadge).label, '\u2605 4.5');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Error Cases
  // ════════════════════════════════════════════════════════════════════

  group('Error recovery', () {
    test('parseMalformedLineNoEquals', () {
      final parser = AmeParser();
      final result = parser.parse(
          'root = txt("Hello")\nthis line has no equals sign\nanother = txt("World")');
      expect(result, isNotNull);
      expect(result, isA<AmeTxt>());
      expect(parser.errors.isNotEmpty, isTrue);
    });

    test('parseUnknownComponent', () {
      final parser = AmeParser();
      final result = parser.parse('root = foobar("test")');
      expect(result, isNotNull);
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).text.contains('Unknown'), isTrue);
      expect(parser.warnings.any((w) => w.contains('Unknown')), isTrue);
    });

    test('parseUnclosedParenthesis', () {
      final parser = AmeParser();
      final result = parser.parse('root = txt("Hello", headline');
      expect(result, isNotNull);
      expect(result, isA<AmeTxt>());
      expect(
          parser.warnings
              .any((w) => w.contains('parenthesis') || w.contains('Unclosed')),
          isTrue);
    });

    test('parseUnclosedString', () {
      final parser = AmeParser();
      parser.parse('root = txt("Hello World)');
      expect(
          parser.warnings
              .any((w) => w.contains('string') || w.contains('Unclosed')),
          isTrue);
    });

    test('parseDuplicateIdentifier', () {
      final parser = AmeParser();
      final result = parser.parse(
          'root = col([header])\nheader = txt("First")\nheader = txt("Second")');
      expect(result, isA<AmeCol>());
      final header = (result as AmeCol).children[0];
      expect((header as AmeTxt).text, 'Second');
      expect(parser.warnings.any((w) => w.contains('Duplicate')), isTrue);
    });

    test('parseEmptyInput', () {
      expect(parse(''), isNull);
    });

    test('parseOnlyComments', () {
      expect(parse('// This is a comment\n// Another comment'), isNull);
    });

    test('parseCommentsInterspersed', () {
      final result = parse(
          '// Header section\nroot = col([header, body])\n// Title\nheader = txt("Welcome", headline)\nbody = txt("Content")');
      expect(result, isA<AmeCol>());
      expect((result as AmeCol).children.length, 2);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Parser Leniency
  // ════════════════════════════════════════════════════════════════════

  group('Leniency', () {
    test('parseLenientUnquotedInputId', () {
      final result = parse('root = input(email, "Email Address", email)');
      expect(result, isA<AmeInput>());
      expect((result as AmeInput).id, 'email');
    });

    test('parseLenientQuotedToolName', () {
      final result =
          parse('root = btn("Save", tool("add_note", title="Notes"), primary)');
      expect(result, isA<AmeBtn>());
      final action = (result as AmeBtn).action as AmeCallTool;
      expect(action.name, 'add_note');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Data Path in Action Arguments
  // ════════════════════════════════════════════════════════════════════

  group('Data path in actions', () {
    test('parseDataRefInActionArg', () {
      final result = parse('root = btn("Directions", uri(\$map_url), text)');
      expect(result, isA<AmeBtn>());
      final action = (result as AmeBtn).action as AmeOpenUri;
      expect(action.uri, '\$map_url');
    });

    test('parseToolActionMultipleArgs', () {
      final result = parse(
          'root = btn("Schedule", tool(create_event, title="Dinner", date="2026-04-15", location="Cafe"), primary)');
      expect(result, isA<AmeBtn>());
      final action = (result as AmeBtn).action as AmeCallTool;
      expect(action.name, 'create_event');
      expect(action.args.length, 3);
      expect(action.args['title'], 'Dinner');
      expect(action.args['date'], '2026-04-15');
      expect(action.args['location'], 'Cafe');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Chart Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Chart', () {
    test('parseChartBar', () {
      final result = parse('root = chart(bar, values=[1,2,3], labels=["a","b","c"])');
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.type, ChartType.bar);
      expect(chart.values, [1.0, 2.0, 3.0]);
      expect(chart.labels, ['a', 'b', 'c']);
    });

    test('parseChartLine', () {
      final result = parse('root = chart(line, values=[10,20], height=180)');
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.type, ChartType.line);
      expect(chart.values, [10.0, 20.0]);
      expect(chart.height, 180);
    });

    test('parseChartPie', () {
      final result = parse('root = chart(pie, values=[30,50,20])');
      expect(result, isA<AmeChart>());
      expect((result as AmeChart).type, ChartType.pie);
    });

    test('parseChartSparkline', () {
      final result =
          parse('root = chart(sparkline, values=[1,3,2,5], height=32, color=success)');
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.type, ChartType.sparkline);
      expect(chart.height, 32);
      expect(chart.color, SemanticColor.success);
    });

    test('parseChartWithDataBinding', () {
      final result = parse(
          'root = chart(bar, values=\$amounts, labels=\$months)\n---\n{"amounts":[100,200,300],"months":["Jan","Feb","Mar"]}');
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.values, [100.0, 200.0, 300.0]);
      expect(chart.labels, ['Jan', 'Feb', 'Mar']);
      expect(chart.valuesPath, isNull);
      expect(chart.labelsPath, isNull);
    });

    test('parseChartUnknownType', () {
      final result = parse('root = chart(donut, values=[1,2])');
      expect(result, isA<AmeChart>());
      expect((result as AmeChart).type, ChartType.bar);
    });

    test('parseChartEmptyValues', () {
      final result = parse('root = chart(bar)');
      expect(result, isA<AmeChart>());
      expect((result as AmeChart).values, isNull);
    });

    test('parseChartMultiSeries', () {
      final result = parse(
          'root = chart(line, series=[[1,2,3],[4,5,6]], labels=["a","b","c"])');
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.series!.length, 2);
      expect(chart.series![0], [1.0, 2.0, 3.0]);
      expect(chart.series![1], [4.0, 5.0, 6.0]);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Code Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Code', () {
    test('parseCode', () {
      final result = parse('root = code("kotlin", "val x = 1")');
      expect(result, isA<AmeCode>());
      final code = result as AmeCode;
      expect(code.language, 'kotlin');
      expect(code.content, 'val x = 1');
      expect(code.title, isNull);
    });

    test('parseCodeWithTitle', () {
      final result = parse('root = code("yaml", "key: val", "config.yml")');
      expect(result, isA<AmeCode>());
      expect((result as AmeCode).title, 'config.yml');
    });

    test('parseCodeWithEscapes', () {
      final result =
          parse('root = code("kotlin", "line1\\nline2\\ttab\\\\end\\"quote")');
      expect(result, isA<AmeCode>());
      expect((result as AmeCode).content, 'line1\nline2\ttab\\end"quote');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Accordion Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Accordion', () {
    test('parseAccordion', () {
      final result = parse(
          'c1 = txt("Child 1")\nc2 = txt("Child 2")\nroot = accordion("Details", [c1, c2])');
      expect(result, isA<AmeAccordion>());
      final acc = result as AmeAccordion;
      expect(acc.title, 'Details');
      expect(acc.children.length, 2);
      expect(acc.expanded, false);
    });

    test('parseAccordionExpanded', () {
      final result =
          parse('c1 = txt("Content")\nroot = accordion("Title", [c1], true)');
      expect(result, isA<AmeAccordion>());
      expect((result as AmeAccordion).expanded, true);
    });

    test('parseAccordionDefaultCollapsed', () {
      final result = parse('root = accordion("FAQ", [txt("Answer")])');
      expect(result, isA<AmeAccordion>());
      expect((result as AmeAccordion).expanded, false);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Carousel Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Carousel', () {
    test('parseCarousel', () {
      final result =
          parse('root = carousel([txt("A"), txt("B"), txt("C")])');
      expect(result, isA<AmeCarousel>());
      expect((result as AmeCarousel).children.length, 3);
    });

    test('parseCarouselWithPeek', () {
      final result =
          parse('root = carousel([txt("A"), txt("B")], peek=32)');
      expect(result, isA<AmeCarousel>());
      expect((result as AmeCarousel).peek, 32);
    });

    test('parseCarouselDefaultPeek', () {
      final result = parse('root = carousel([txt("A")])');
      expect(result, isA<AmeCarousel>());
      expect((result as AmeCarousel).peek, 24);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Callout Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Callout', () {
    test('parseCalloutInfo', () {
      final result = parse('root = callout(info, "This is informational")');
      expect(result, isA<AmeCallout>());
      final co = result as AmeCallout;
      expect(co.type, CalloutType.info);
      expect(co.content, 'This is informational');
      expect(co.title, isNull);
    });

    test('parseCalloutWarning', () {
      final result = parse('root = callout(warning, "Proceed with caution")');
      expect((result as AmeCallout).type, CalloutType.warning);
    });

    test('parseCalloutWithTitle', () {
      final result = parse(
          'root = callout(tip, "Use keyboard shortcuts", "Pro Tip")');
      expect(result, isA<AmeCallout>());
      final co = result as AmeCallout;
      expect(co.type, CalloutType.tip);
      expect(co.title, 'Pro Tip');
    });

    test('parseCalloutAllTypes', () {
      for (final entry in [
        ('info', CalloutType.info),
        ('warning', CalloutType.warning),
        ('error', CalloutType.error),
        ('success', CalloutType.success),
        ('tip', CalloutType.tip),
      ]) {
        final result = parse('root = callout(${entry.$1}, "msg")');
        expect(result, isA<AmeCallout>());
        expect((result as AmeCallout).type, entry.$2,
            reason: 'callout(${entry.$1}) type mismatch');
      }
    });

    test('parseCalloutUnknownType', () {
      final result = parse('root = callout(banana, "msg")');
      expect(result, isA<AmeCallout>());
      expect((result as AmeCallout).type, CalloutType.info);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Timeline Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Timeline', () {
    test('parseTimeline', () {
      final result = parse(
          's1 = timeline_item("Step 1", "Done", done)\ns2 = timeline_item("Step 2", "In progress", active)\nroot = timeline([s1, s2])');
      expect(result, isA<AmeTimeline>());
      final tl = result as AmeTimeline;
      expect(tl.children.length, 2);
      final item0 = tl.children[0] as AmeTimelineItem;
      expect(item0.title, 'Step 1');
      expect(item0.status, TimelineStatus.done);
      expect((tl.children[1] as AmeTimelineItem).status, TimelineStatus.active);
    });

    test('parseTimelineItem', () {
      final result = parse('root = timeline_item("Title", "Subtitle", done)');
      expect(result, isA<AmeTimelineItem>());
      final item = result as AmeTimelineItem;
      expect(item.title, 'Title');
      expect(item.subtitle, 'Subtitle');
      expect(item.status, TimelineStatus.done);
    });

    test('parseTimelineItemDefaultStatus', () {
      final result = parse('root = timeline_item("Upcoming")');
      expect(result, isA<AmeTimelineItem>());
      expect((result as AmeTimelineItem).status, TimelineStatus.pending);
    });

    test('parseTimelineItemAllStatuses', () {
      for (final entry in [
        ('done', TimelineStatus.done),
        ('active', TimelineStatus.active),
        ('pending', TimelineStatus.pending),
        ('error', TimelineStatus.error),
      ]) {
        final result =
            parse('root = timeline_item("t", "s", ${entry.$1})');
        expect((result as AmeTimelineItem).status, entry.$2);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // v1.1 Semantic Color Tests
  // ════════════════════════════════════════════════════════════════════

  group('v1.1 Semantic Colors', () {
    test('parseTxtWithColor', () {
      final result = parse('root = txt("Alert text", body, color=warning)');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).color, SemanticColor.warning);
    });

    test('parseTxtWithoutColor', () {
      final result = parse('root = txt("Normal", headline)');
      expect(result, isA<AmeTxt>());
      expect((result as AmeTxt).color, isNull);
    });

    test('parseBadgeWithColor', () {
      final result = parse('root = badge("Live", success, color=success)');
      expect(result, isA<AmeBadge>());
      final badge = result as AmeBadge;
      expect(badge.variant, BadgeVariant.success);
      expect(badge.color, SemanticColor.success);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // WP#5b.1 Regression: Chart $path inside each()
  // ════════════════════════════════════════════════════════════════════

  group('Chart inside each()', () {
    test('chartInsideEachResolvesPerItemScope', () {
      final result = parse(
          'root = col([results])\nresults = each(\$restaurants, tpl)\ntpl = col([name, spending])\nname = txt(\$name, title)\nspending = chart(bar, values=\$sales)\n---\n{"restaurants":[{"name":"Luigi\'s","sales":[10,20,30]},{"name":"Bella\'s","sales":[40,50,60]}]}');
      expect(result, isA<AmeCol>());
      final col = result as AmeCol;
      final expanded = col.children[0] as AmeCol;
      expect(expanded.children.length, 2);

      final tpl1 = expanded.children[0] as AmeCol;
      expect((tpl1.children[0] as AmeTxt).text, "Luigi's");
      final chart1 = tpl1.children[1] as AmeChart;
      expect(chart1.values, [10.0, 20.0, 30.0]);
      expect(chart1.valuesPath, isNull);

      final tpl2 = expanded.children[1] as AmeCol;
      expect((tpl2.children[0] as AmeTxt).text, "Bella's");
      final chart2 = tpl2.children[1] as AmeChart;
      expect(chart2.values, [40.0, 50.0, 60.0]);
      expect(chart2.valuesPath, isNull);
    });
  });
}
