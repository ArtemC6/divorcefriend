import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Колесо рандомайзера',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.white,
          surface: const Color(0xFF121212),
        ).copyWith(background: const Color(0xFF121212)),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: Colors.deepPurpleAccent.withOpacity(0.3),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurpleAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 8,
          centerTitle: true,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF23234A).withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const RandomizerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RandomizerScreen extends StatefulWidget {
  const RandomizerScreen({super.key});

  @override
  State<RandomizerScreen> createState() => _RandomizerScreenState();
}

class _RandomizerScreenState extends State<RandomizerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<String> _items = [];
  String _selectedItem = '';
  late AnimationController _animationController;
  double _rotationAngle = 0.0;
  final Random _random = Random();
  bool _showResult = false;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _animationController.addListener(() {
      setState(() {
        final t = Curves.easeInOut.transform(_animationController.value);
        _rotationAngle = t * 2 * pi * 5 + (Curves.elasticOut.transform(_animationController.value) * 0.1);
      });
    });
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _selectRandomItem();
        setState(() {
          _isSpinning = false;
        });
      }
    });
    _loadItems();
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('wheel_items');
    if (itemsJson != null) {
      setState(() {
        _items = List<String>.from(json.decode(itemsJson));
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wheel_items', json.encode(_items));
  }

  void _addItem() {
    if (_textController.text.trim().isNotEmpty) {
      final newItem = _textController.text.trim();
      setState(() {
        _items.add(newItem);
        _textController.clear();
        _saveItems();
      });
      // Ensure the AnimatedList is updated after the setState
      Future.microtask(() {
        _listKey.currentState?.insertItem(_items.length - 1, duration: const Duration(milliseconds: 500));
      });
    }
  }

  void _editItem(int index) {
    _textController.text = _items[index];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: AlertDialog(
                title: const Text('Редактировать элемент', style: TextStyle(color: Colors.white)),
                content: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Новое значение',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _textController.clear();
                    },
                    child: const Text('Отмена', style: TextStyle(color: Colors.deepPurpleAccent)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _items[index] = _textController.text.trim();
                        _textController.clear();
                        _saveItems();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Сохранить', style: TextStyle(color: Colors.tealAccent)),
                  ),
                ],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                backgroundColor: const Color(0xFF23234A).withOpacity(0.7),
              ),
            ),
          ),
        );
      },
    );
  }

  void _deleteItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      _saveItems();
      _listKey.currentState?.removeItem(
        index,
            (context, animation) => _buildAnimatedListItem(removed, index, animation),
        duration: const Duration(milliseconds: 500),
      );
      if (_selectedItem.isNotEmpty && _items.isEmpty) {
        _selectedItem = '';
      }
    });
  }

  void _spinWheel() {
    if (_items.isEmpty || _isSpinning) return;
    setState(() {
      _selectedItem = '';
      _showResult = false;
      _isSpinning = true;
      _animationController.reset();
      // Добавляем случайное смещение для более естественного вращения
      _rotationAngle = _random.nextDouble() * 2 * pi;
      _animationController.forward();
    });
  }

  void _selectRandomItem() {
    if (_items.isEmpty) return;

    setState(() {
      // Рассчитываем индекс с учетом текущего угла поворота
      final normalizedAngle = _rotationAngle % (2 * pi);
      final sectorAngle = 2 * pi / _items.length;
      int selectedIndex = _items.length - 1 - (normalizedAngle / sectorAngle).floor() % _items.length;
      _selectedItem = _items[selectedIndex];
      _showResult = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, color: Colors.amberAccent),
              const SizedBox(width: 12),
              Text('Выбрано: $_selectedItem',
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 12,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      );
    });
  }

  Widget _buildAnimatedListItem(String item, int index, Animation<double> animation) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                    boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    title: Text(item, style: const TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: () => _editItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () => _deleteItem(index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final wheelSize = size.width * 0.8; // Адаптивный размер колеса

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Разведи друга',
          style: TextStyle(
            color: Colors.white,
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
          ),
        ),
        child: SafeArea(
          bottom: !isKeyboardVisible, // Отключаем bottom SafeArea при открытой клавиатуре
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                children: [
                  // Поле ввода
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: size.height * 0.074,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.black.withOpacity(0.2),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: TextField(
                                    controller: _textController,
                                    style: TextStyle(color: Colors.white, fontSize: size.width * 0.04),
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: size.height * 0.02,
                                        horizontal: size.width * 0.04,
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      labelText: 'Введите элемент',
                                      labelStyle: TextStyle(color: Colors.grey[400]),
                                      suffixIcon: AnimatedScale(
                                        scale: _textController.text.trim().isNotEmpty ? 1.1 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: IconButton(
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          onPressed: _addItem,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) => _addItem(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.035),

                  // Колесо
                  SizedBox(
                    height: wheelSize * 1.2,
                    child: Center(
                      child: GestureDetector(
                        onTap: _spinWheel,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              width: _isSpinning ? wheelSize * 1.1 : wheelSize,
                              height: _isSpinning ? wheelSize * 1.1 : wheelSize,
                              child: Transform.rotate(
                                angle: _rotationAngle,
                                child: CustomPaint(
                                  painter: WheelPainter(items: _items),
                                  size: Size(wheelSize, wheelSize),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, -wheelSize * 0.5),
                                  child: Container(
                                    width: wheelSize * 0.25,
                                    height: wheelSize * 0.25,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 0.8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.arrow_drop_down,
                                      size: wheelSize * 0.25,
                                      color: _isSpinning ? Colors.amberAccent : Colors.deepPurpleAccent,
                                    ),
                                  ),
                                );
                              },
                            ),
                            ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: _isSpinning ? wheelSize * 0.22 : wheelSize * 0.2,
                                  height: _isSpinning ? wheelSize * 0.22 : wheelSize * 0.2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E).withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.tealAccent.withOpacity(0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.casino,
                                    size: wheelSize * 0.1,
                                    color: Colors.deepPurpleAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  // Результат
// Результат
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _showResult && _selectedItem.isNotEmpty
                        ? Padding(
                      key: ValueKey(_selectedItem),
                      padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.07,
                          vertical: size.height * 0.018,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurpleAccent.withOpacity(0.7),
                              Colors.tealAccent.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'Результат: $_selectedItem',
                          style: TextStyle(
                            fontSize: size.width * 0.058,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                  // Список элементов
                  SizedBox(
                    height: size.height * (isKeyboardVisible ? 0.2 : 0.3),
                    child: _items.isEmpty
                        ? Center(
                      child: Text(
                        textAlign:  TextAlign.center,
                        'Добавьте элементы для рандомизации',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width * 0.05,
                        ),
                      ),
                    )
                        : AnimatedList(
                      key: _listKey,
                      initialItemCount: _items.length,
                      itemBuilder: (context, index, animation) {
                        return _buildAnimatedListItem(_items[index], index, animation);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<String> items;

  WheelPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    if (items.isEmpty) {
      paint.color = const Color(0xFF2D2D2D);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final sweepAngle = 2 * pi / items.length;

    // Рисуем сектора в обратном порядке, чтобы первый элемент был сверху
    for (int i = 0; i < items.length; i++) {
      final startAngle = i * sweepAngle - pi / 2; // Смещаем на -90 градусов, чтобы первый элемент был сверху
      paint.color = _getColorForIndex(i);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      // 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

      // Разделительные линии между секторами
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        ),
        linePaint,
      );

      // Текст элемента
      final textPainter = TextPainter(
        text: TextSpan(
          text: items[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: max(12, size.width * 0.05),
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textAngle = startAngle + sweepAngle / 2;
      final textRadius = radius * 0.6;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2); // Поворачиваем текст для правильной ориентации
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Центральный круг
    paint.color = const Color(0xFF1E1E1E);
    canvas.drawCircle(center, radius * 0.1, paint);

    // Внешняя граница колеса
    final borderPaint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, borderPaint);

    // Свечение вокруг колеса
    final glowPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(center, radius - 4, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.deepPurpleAccent,
      Colors.amberAccent,
      Colors.pinkAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.lightGreenAccent,
    ];
    return colors[index % colors.length].withOpacity(0.85);
  }
}