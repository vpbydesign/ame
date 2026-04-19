import 'package:flutter/material.dart' hide Align;
import 'package:flutter_test/flutter_test.dart';
import 'package:ame_flutter_ui/ame_flutter_ui.dart';

void main() {
  Widget wrap(AmeNode node, {AmeFormState? formState, void Function(AmeAction)? onAction}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AmeRenderer(
            node: node,
            formState: formState ?? AmeFormState(),
            onAction: onAction ?? (_) {},
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Primitive Rendering — each type renders without error
  // ════════════════════════════════════════════════════════════════════

  group('Primitive rendering', () {
    testWidgets('renders txt', (tester) async {
      await tester.pumpWidget(wrap(const AmeTxt(text: 'Hello World')));
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders txt with style', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeTxt(text: 'Title', style: TxtStyle.headline)));
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester
          .pumpWidget(wrap(const AmeIcon(name: 'star', size: 24)));
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders icon fallback for unknown name', (tester) async {
      await tester
          .pumpWidget(wrap(const AmeIcon(name: 'nonexistent_icon')));
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('renders divider', (tester) async {
      await tester.pumpWidget(wrap(const AmeDivider()));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders spacer', (tester) async {
      await tester.pumpWidget(wrap(const AmeSpacer(height: 16)));
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 16);
    });

    testWidgets('renders badge', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeBadge(label: 'New', variant: BadgeVariant.success)));
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('renders progress', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeProgress(value: 0.5, label: '50%')));
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders progress without label', (tester) async {
      await tester.pumpWidget(wrap(const AmeProgress(value: 0.7)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders code block', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCode(language: 'dart', content: 'void main() {}')));
      expect(find.text('void main() {}'), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('renders code block with title', (tester) async {
      await tester.pumpWidget(wrap(
          const AmeCode(language: 'dart', content: 'x', title: 'Main.dart')));
      expect(find.text('Main.dart'), findsOneWidget);
    });

    testWidgets('renders callout info', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCallout(type: CalloutType.info, content: 'Note')));
      expect(find.text('Note'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('renders callout warning', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCallout(type: CalloutType.warning, content: 'Warn')));
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('renders callout error', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCallout(type: CalloutType.error, content: 'Err')));
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('renders callout success', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCallout(type: CalloutType.success, content: 'Ok')));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders callout tip', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeCallout(type: CalloutType.tip, content: 'Tip')));
      expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    });

    testWidgets('renders callout with title', (tester) async {
      await tester.pumpWidget(wrap(const AmeCallout(
          type: CalloutType.info, content: 'Body', title: 'Header')));
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('renders timeline item standalone', (tester) async {
      await tester.pumpWidget(wrap(const AmeTimelineItem(
          title: 'Step', subtitle: 'Done', status: TimelineStatus.done)));
      expect(find.text('Step'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Container types render children
  // ════════════════════════════════════════════════════════════════════

  group('Container rendering', () {
    testWidgets('col renders children', (tester) async {
      await tester.pumpWidget(wrap(const AmeCol(children: [
        AmeTxt(text: 'A'),
        AmeTxt(text: 'B'),
      ])));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('row renders children', (tester) async {
      await tester.pumpWidget(wrap(const AmeRow(children: [
        AmeTxt(text: 'Left'),
        AmeTxt(text: 'Right'),
      ])));
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('card renders children', (tester) async {
      await tester.pumpWidget(wrap(const AmeCard(children: [
        AmeTxt(text: 'Inside Card'),
      ])));
      expect(find.text('Inside Card'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('data list renders children with dividers', (tester) async {
      await tester.pumpWidget(wrap(const AmeDataList(
        children: [AmeTxt(text: 'Item 1'), AmeTxt(text: 'Item 2')],
        dividers: true,
      )));
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('data list without dividers', (tester) async {
      await tester.pumpWidget(wrap(const AmeDataList(
        children: [AmeTxt(text: 'A'), AmeTxt(text: 'B')],
        dividers: false,
      )));
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('table renders headers and rows', (tester) async {
      await tester.pumpWidget(wrap(const AmeTable(
        headers: ['Name', 'Age'],
        rows: [
          ['Alice', '30'],
          ['Bob', '25'],
        ],
      )));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('timeline renders items', (tester) async {
      await tester.pumpWidget(wrap(const AmeTimeline(children: [
        AmeTimelineItem(title: 'Step 1', status: TimelineStatus.done),
        AmeTimelineItem(title: 'Step 2', status: TimelineStatus.active),
      ])));
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Interactive behavior
  // ════════════════════════════════════════════════════════════════════

  group('Interactive behavior', () {
    testWidgets('btn dispatches onAction on tap', (tester) async {
      AmeAction? received;
      await tester.pumpWidget(wrap(
        const AmeBtn(
          label: 'Click Me',
          action: AmeNavigate(route: 'home'),
        ),
        onAction: (a) => received = a,
      ));
      await tester.tap(find.text('Click Me'));
      await tester.pump();
      expect(received, isA<AmeNavigate>());
      expect((received as AmeNavigate).route, 'home');
    });

    testWidgets('btn with submit resolves form refs', (tester) async {
      AmeAction? received;
      final formState = AmeFormState();
      formState.setInput('email', 'test@test.com');

      await tester.pumpWidget(wrap(
        const AmeBtn(
          label: 'Submit',
          action: AmeSubmit(
            toolName: 'send_email',
            staticArgs: {r'to': r'${input.email}'},
          ),
        ),
        formState: formState,
        onAction: (a) => received = a,
      ));
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(received, isA<AmeCallTool>());
      final callTool = received as AmeCallTool;
      expect(callTool.name, 'send_email');
      expect(callTool.args['to'], 'test@test.com');
    });

    testWidgets('btn styles render correct button types', (tester) async {
      await tester.pumpWidget(wrap(const AmeBtn(
        label: 'Primary',
        action: AmeNavigate(route: 'x'),
        style: BtnStyle.primary,
      )));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('btn outline style', (tester) async {
      await tester.pumpWidget(wrap(const AmeBtn(
        label: 'Outline',
        action: AmeNavigate(route: 'x'),
        style: BtnStyle.outline,
      )));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('btn text style', (tester) async {
      await tester.pumpWidget(wrap(const AmeBtn(
        label: 'Text',
        action: AmeNavigate(route: 'x'),
        style: BtnStyle.text,
      )));
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('btn with icon shows icon', (tester) async {
      await tester.pumpWidget(wrap(const AmeBtn(
        label: 'Call',
        action: AmeNavigate(route: 'x'),
        icon: 'phone',
      )));
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('input text field renders', (tester) async {
      await tester.pumpWidget(wrap(
        const AmeInput(id: 'name', label: 'Name'),
      ));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('input updates form state on change', (tester) async {
      final formState = AmeFormState();
      await tester.pumpWidget(wrap(
        const AmeInput(id: 'name', label: 'Name'),
        formState: formState,
      ));
      await tester.enterText(find.byType(TextField), 'Alice');
      expect(formState.getInput('name'), 'Alice');
    });

    testWidgets('toggle renders switch', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeToggle(id: 'agree', label: 'I agree')));
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('I agree'), findsOneWidget);
    });

    testWidgets('toggle updates form state', (tester) async {
      final formState = AmeFormState();
      await tester.pumpWidget(wrap(
        const AmeToggle(id: 'notify', label: 'Notifications'),
        formState: formState,
      ));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(formState.getToggle('notify'), true);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Accordion
  // ════════════════════════════════════════════════════════════════════

  group('Accordion', () {
    testWidgets('starts collapsed by default', (tester) async {
      await tester.pumpWidget(wrap(const AmeAccordion(
        title: 'Details',
        children: [AmeTxt(text: 'Hidden')],
      )));
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('starts expanded when expanded=true', (tester) async {
      await tester.pumpWidget(wrap(const AmeAccordion(
        title: 'Details',
        children: [AmeTxt(text: 'Visible')],
        expanded: true,
      )));
      expect(find.text('Visible'), findsOneWidget);
    });

    testWidgets('toggles on tap', (tester) async {
      await tester.pumpWidget(wrap(const AmeAccordion(
        title: 'Details',
        children: [AmeTxt(text: 'Content')],
      )));
      expect(find.text('Content'), findsNothing);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsNothing);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Chart
  // ════════════════════════════════════════════════════════════════════

  group('Chart', () {
    testWidgets('shows no data message when empty', (tester) async {
      await tester.pumpWidget(wrap(const AmeChart(type: ChartType.bar)));
      expect(find.text('No chart data'), findsOneWidget);
    });

    testWidgets('renders bar chart with data', (tester) async {
      await tester.pumpWidget(wrap(const AmeChart(
        type: ChartType.bar,
        values: [1.0, 2.0, 3.0],
      )));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders pie chart', (tester) async {
      await tester.pumpWidget(wrap(const AmeChart(
        type: ChartType.pie,
        values: [30.0, 50.0, 20.0],
      )));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Skeleton / Depth Limit
  // ════════════════════════════════════════════════════════════════════

  group('Structural', () {
    testWidgets('ref shows skeleton', (tester) async {
      await tester.pumpWidget(wrap(const AmeRef(id: 'header')));
      await tester.pump();
      expect(find.byType(AmeSkeleton), findsOneWidget);
    });

    testWidgets('each shows skeleton', (tester) async {
      await tester.pumpWidget(
          wrap(const AmeEach(dataPath: 'items', templateId: 'tpl')));
      await tester.pump();
      expect(find.byType(AmeSkeleton), findsOneWidget);
    });

    testWidgets('depth limit shows warning', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmeRenderer(
            node: const AmeTxt(text: 'Deep'),
            onAction: (_) {},
            formState: AmeFormState(),
            depth: 13,
          ),
        ),
      ));
      expect(find.textContaining('Max nesting depth'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Form State
  // ════════════════════════════════════════════════════════════════════

  group('AmeFormState', () {
    test('collectValues merges inputs and toggles', () {
      final state = AmeFormState();
      state.setInput('name', 'Alice');
      state.setInput('email', 'a@b.com');
      state.setToggle('agree', true);

      final values = state.collectValues();
      expect(values['name'], 'Alice');
      expect(values['email'], 'a@b.com');
      expect(values['agree'], 'true');
    });

    test('resolveInputReferences replaces tokens', () {
      final state = AmeFormState();
      state.setInput('to', 'bob@test.com');
      state.setInput('body', 'Hello');

      final resolved = state.resolveInputReferences({
        'recipient': r'${input.to}',
        'message': r'${input.body}',
        'static': 'unchanged',
      });

      expect(resolved['recipient'], 'bob@test.com');
      expect(resolved['message'], 'Hello');
      expect(resolved['static'], 'unchanged');
    });

    test('resolveInputReferences preserves unknown refs', () {
      final state = AmeFormState();
      final resolved = state.resolveInputReferences({
        'val': r'${input.missing}',
      });
      expect(resolved['val'], r'${input.missing}');
    });

    test('getInput returns default when not set', () {
      final state = AmeFormState();
      expect(state.getInput('x'), '');
      expect(state.getInput('x', 'fallback'), 'fallback');
    });

    test('getToggle returns default when not set', () {
      final state = AmeFormState();
      expect(state.getToggle('x'), false);
      expect(state.getToggle('x', true), true);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // AmeIcons
  // ════════════════════════════════════════════════════════════════════

  group('AmeIcons', () {
    test('registry has 57 entries', () {
      expect(AmeIcons.registryCount, 57);
    });

    test('resolve returns fallback for unknown', () {
      expect(AmeIcons.resolve('xyz_nonexistent'), Icons.help_outline);
    });

    test('contentDescription replaces underscores', () {
      expect(AmeIcons.contentDescription('check_circle'), 'check circle');
    });
  });
}
