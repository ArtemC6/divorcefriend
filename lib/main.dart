import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

void vibrate(int duration) {
  HapticFeedback.vibrate();
  Future.delayed(Duration(milliseconds: duration ~/ 3), () {
    HapticFeedback.vibrate();
  });
}

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  await Hive.openBox<Item>('wheel_items');
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

class Item {
  String text;
  double weight;

  Item(this.text, [this.weight = 1.0]);
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 0;

  @override
  Item read(BinaryReader reader) {
    final text = reader.readString();
    final weight = reader.readDouble();
    return Item(text, weight);
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeString(obj.text);
    writer.writeDouble(obj.weight);
  }
}

class RandomizerScreen extends StatefulWidget {
  const RandomizerScreen({super.key});

  @override
  State<RandomizerScreen> createState() => _RandomizerScreenState();
}

class _RandomizerScreenState extends State<RandomizerScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Item> _items = [];
  List<String> _history = [];
  String _selectedItem = '';
  late AnimationController _animationController;
  late Animation<double> _spinAnimation;
  double _rotationAngle = 0.0;
  final Random _random = Random();
  bool _showResult = false;
  bool _isSpinning = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const _DecelerationCurve(),
      ),
    )..addListener(() {
      setState(() {
        _rotationAngle = _spinAnimation.value * 2 * pi * (_random.nextInt(5) + 5);
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
    _weightController.dispose();
    _animationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final box = Hive.box<Item>('wheel_items');
    setState(() {
      _items = box.values.toList();
    });
  }

  Future<void> _saveItems() async {
    final box = Hive.box<Item>('wheel_items');
    await box.clear();
    for (int i = 0; i < _items.length; i++) {
      await box.putAt(i, _items[i]);
    }
  }

  void _addItem() {
    if (_textController.text.trim().isNotEmpty) {
      final newItem = Item(
        _textController.text.trim(),
        double.tryParse(_weightController.text) ?? 1.0,
      );
      setState(() {
        _items.add(newItem);
        _textController.clear();
        _weightController.clear();
        _saveItems();
      });
      Future.microtask(() {
        _listKey.currentState?.insertItem(_items.length - 1, duration: const Duration(milliseconds: 500));
      });
    }
  }

  void _editItem(int index) {
    _textController.text = _items[index].text;
    _weightController.text = _items[index].weight.toString();
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
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Название',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _weightController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Вес (1.0 и выше)',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _textController.clear();
                      _weightController.clear();
                    },
                    child: const Text('Отмена', style: TextStyle(color: Colors.deepPurpleAccent)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _items[index] = Item(
                          _textController.text.trim(),
                          double.tryParse(_weightController.text) ?? 1.0,
                        );
                        _textController.clear();
                        _weightController.clear();
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
      // Очищаем историю когда удалены все элементы
      if (_items.isEmpty) {
        _history.clear();
      }
    });
  }

  void _spinWheel() {
    if (_items.isEmpty || _isSpinning) return;
    vibrate(200);
    setState(() {
      _selectedItem = '';
      _showResult = false;
      _isSpinning = true;
      _animationController.duration = Duration(milliseconds: 4000 + _random.nextInt(2000));
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _selectRandomItem() {
    if (_items.isEmpty) return;

    // Weighted random selection
    double totalWeight = _items.fold(0, (sum, item) => sum + max(1.0, item.weight));
    double randomValue = _random.nextDouble() * totalWeight;
    double currentWeight = 0;
    int selectedIndex = 0;

    for (int i = 0; i < _items.length; i++) {
      currentWeight += max(1.0, _items[i].weight);
      if (randomValue <= currentWeight) {
        selectedIndex = i;
        break;
      }
    }

    // Adjust final rotation to point to selected item
    final sweepAngle = 2 * pi / _items.length;
    final targetAngle = (selectedIndex * sweepAngle - pi / 2) % (2 * pi);
    setState(() {
      _rotationAngle = (_rotationAngle ~/ (2 * pi)) * 2 * pi + targetAngle;
      _selectedItem = _items[selectedIndex].text;
      _showResult = true;
      _history.insert(0, _selectedItem);
      if (_history.length > 5) _history.removeLast();
    });

    vibrate(300);

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

  Widget _buildAnimatedListItem(Item item, int index, Animation<double> animation) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: Dismissible(
            key: ValueKey(index),
            background: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.red.withOpacity(0.7), Colors.red.withOpacity(0.4)],
                ),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteItem(index),
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        '${item.text} (вес: ${item.weight.toStringAsFixed(1)})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Row(
                              children: const [
                                Icon(Icons.edit, color: Colors.deepPurpleAccent),
                                SizedBox(width: 10),
                                Text('Редактировать'),
                              ],
                            ),
                            onTap: () => _editItem(index),
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: const [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Удалить'),
                              ],
                            ),
                            onTap: () => _deleteItem(index),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final wheelSize = size.width * 0.8;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.deepPurpleAccent, Colors.tealAccent],
                ),
              ),
              child: const Icon(Icons.casino, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Text(
              'Разведи друга',
              style: TextStyle(
                color: Colors.white,
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
          bottom: !isKeyboardVisible,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
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
                                filter: ImageFilter.blur(sigmaX: 22.0, sigmaY: 32.0),
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
                      SizedBox(width: size.width * 0.02),
                      Expanded(
                        flex: 1,
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
                                    controller: _weightController,
                                    style: TextStyle(color: Colors.white, fontSize: size.width * 0.04),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        final oldText = oldValue.text;
                                        final newText = newValue.text;
                                        if (newText == '') return newValue;
                                        if (newText == ',') return newValue.copyWith(text: '.');
                                        if (newText == '.') return newValue;
                                        if (newText.startsWith(',') || newText.startsWith('.') || newText.startsWith(RegExp(r'[^\d.,]'))) return oldValue;
                                        if (newText.split(RegExp(r'[,.]')).length > 2) return oldValue;

                                        if (newText.contains(RegExp(r'[,.]'))) {
                                          final split = newText.split(RegExp(r'[,.]'));
                                          if (split[1].length > 2) return oldValue;
                                        }

                                        if (newText != '' && double.tryParse(newText.replaceAll(',', '.')) == null) return oldValue;

                                        return newValue;
                                      }),
                                    ],
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: size.height * 0.02,
                                        horizontal: size.width * 0.04,
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      labelText: 'Вес',
                                      labelStyle: TextStyle(color: Colors.grey[400]),
                                      suffixIcon: AnimatedScale(
                                        scale: _textController.text.trim().isNotEmpty &&
                                            _weightController.text.trim().isNotEmpty ? 1.1 : 1.0,
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
                  SizedBox(
                    height: wheelSize * 1.2,
                    child: Center(
                      child: GestureDetector(
                        onTap: _spinWheel,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, child) {
                                return Container(
                                  width: _isSpinning ? wheelSize * 1.2 : wheelSize * 1.05,
                                  height: _isSpinning ? wheelSize * 1.2 : wheelSize * 1.05,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.tealAccent.withOpacity(
                                          _isSpinning ? 0.4 * (0.5 + 0.5 * sin(_glowController.value * 2 * pi)) : 0.1,
                                        ),
                                        blurRadius: _isSpinning ? 40 : 20,
                                        spreadRadius: _isSpinning ? 15 : 5,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
                            if(!_selectedItem.isNotEmpty)

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
                  if (_history.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'История',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: size.width * 0.04,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: size.height * 0.01),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _history.map((item) {
                              return GestureDetector(
                                onLongPress: () {
                                  setState(() {
                                    _history.remove(item);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Удалено: $item'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.red.withOpacity(0.7),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepPurpleAccent.withOpacity(0.6),
                                        Colors.tealAccent.withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: size.height * (isKeyboardVisible ? 0.2 : 0.25),
                    child: _items.isEmpty
                        ? Center(
                      child: Text(
                        textAlign: TextAlign.center,
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
  final List<Item> items;

  WheelPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final totalWeight = items.fold(0.0, (sum, item) => sum + max(1.0, item.weight));

    if (items.isEmpty) {
      paint.color = const Color(0xFF2D2D2D);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -pi / 2;
    for (int i = 0; i < items.length; i++) {
      final sweepAngle = (2 * pi * max(1.0, items[i].weight)) / totalWeight;
      paint.color = _getColorForIndex(i);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

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

      final textPainter = TextPainter(
        text: TextSpan(
          text: items[i].text,
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
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();

      startAngle += sweepAngle;
    }

    paint.color = const Color(0xFF1E1E1E);
    canvas.drawCircle(center, radius * 0.1, paint);

    final borderPaint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, borderPaint);

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

class _DecelerationCurve extends Curve {
  const _DecelerationCurve();

  @override
  double transformInternal(double t) {
    return 1 - pow(1 - t, 4).toDouble();
  }
}