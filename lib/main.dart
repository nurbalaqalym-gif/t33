import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LifeApp());

const int kCols = 52; // в году 52 недели: одна строка = один год
const double kLabelWidth = 26;

String fmtInt(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

class LifeApp extends StatelessWidget {
  const LifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Жизнь в неделях',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _birth;
  int _targetYears = 80; // сколько лет мы "планируем" прожить
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final birthMs = prefs.getInt('birth');
    final target = prefs.getInt('target') ?? 80;
    if (!mounted) return;
    setState(() {
      _birth = birthMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(birthMs);
      _targetYears = target.clamp(60, 100);
      _loading = false;
    });
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25, 6, 15),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Дата рождения',
    );
    if (picked == null || !mounted) return;
    setState(() => _birth = picked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('birth', picked.millisecondsSinceEpoch);
  }

  Future<void> _saveTarget(int years) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('target', years);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Жизнь в неделях'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cake),
            tooltip: 'Дата рождения',
            onPressed: _pickBirth,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _birth == null
            ? _buildWelcome()
            : _buildContent(cs),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Вся жизнь на одном экране',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Каждая клетка — одна неделя. Одна строка — один год. '
              'Посмотрите, сколько недель уже позади и сколько впереди.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickBirth,
              icon: const Icon(Icons.cake),
              label: const Text('Выбрать дату рождения'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final now = DateTime.now();
    final totalWeeks = _targetYears * kCols;
    final rawLived = now.difference(_birth!).inDays ~/ 7;
    final lived = rawLived.clamp(0, totalWeeks);
    final left = totalWeeks - lived;
    final percent = lived / totalWeeks;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmtInt(lived)} недель прожито',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  left > 0
                      ? 'Впереди примерно ${fmtInt(left)} из ${fmtInt(totalWeeks)}'
                      : 'Это больше, чем $_targetYears лет',
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(percent * 100).toStringAsFixed(1).replaceAll('.', ',')}% '
                  'от $_targetYears лет',
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ожидаемая продолжительность жизни: $_targetYears лет',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: _targetYears.toDouble(),
          min: 60,
          max: 100,
          divisions: 40,
          label: '$_targetYears',
          onChanged: (v) => setState(() => _targetYears = v.round()),
          onChangeEnd: (v) => _saveTarget(v.round()),
        ),
        const SizedBox(height: 8),
        // Сама картина жизни: рисуем на холсте
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cell = (width - kLabelWidth) / kCols;
            return CustomPaint(
              size: Size(width, _targetYears * cell),
              painter: LifeGridPainter(
                years: _targetYears,
                lived: lived,
                livedColor: cs.primary,
                currentColor: cs.tertiary,
                futureColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(fontSize: 10, color: cs.outline),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Legend(color: cs.primary, text: 'Прожито'),
            _Legend(color: cs.tertiary, text: 'Эта неделя'),
            _Legend(color: cs.surfaceContainerHighest, text: 'Впереди'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Числа слева — возраст. Год здесь условно равен 52 неделям.',
          style: TextStyle(color: cs.outline, fontSize: 12),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

// CustomPainter: рисуем сетку клеток вручную, а не виджетами.
// Так 4 000+ клеток рисуются мгновенно.
class LifeGridPainter extends CustomPainter {
  LifeGridPainter({
    required this.years,
    required this.lived,
    required this.livedColor,
    required this.currentColor,
    required this.futureColor,
    required this.labelStyle,
  });

  final int years;
  final int lived;
  final Color livedColor;
  final Color currentColor;
  final Color futureColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width - kLabelWidth) / kCols;
    final gap = cell * 0.2;
    final paint = Paint();

    for (var row = 0; row < years; row++) {
      for (var col = 0; col < kCols; col++) {
        final index = row * kCols + col;

        if (index < lived) {
          paint.color = livedColor;
        } else if (index == lived) {
          paint.color = currentColor;
        } else {
          paint.color = futureColor;
        }

        final rect = Rect.fromLTWH(
          kLabelWidth + col * cell + gap / 2,
          row * cell + gap / 2,
          cell - gap,
          cell - gap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
          paint,
        );
      }

      // Подпись возраста каждые 10 лет
      if ((row + 1) % 10 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${row + 1}', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(0, row * cell + (cell - tp.height) / 2));
      }
    }
  }

  // Перерисовываем только когда что-то изменилось
  @override
  bool shouldRepaint(LifeGridPainter old) =>
      old.years != years ||
      old.lived != lived ||
      old.livedColor != livedColor ||
      old.currentColor != currentColor ||
      old.futureColor != futureColor;
}
