import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db_helpers/db_reservations.dart';
import '../main.dart';
import '../models/gym_class.dart';
import '../providers/provider_reservations.dart';
import 'reservation_confirmation_screen.dart';

class MatSelectionScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mat_selection';
  final GymClass gymClass;

  const MatSelectionScreen({super.key, required this.gymClass});

  @override
  ConsumerState<MatSelectionScreen> createState() => _MatSelectionScreenState();
}

class _MatSelectionScreenState extends ConsumerState<MatSelectionScreen> {
  int? _selectedMat;
  bool _isSubmitting = false;

  List<List<int>> _buildMatRows(int capacity) {
    final safeCapacity = capacity <= 0 ? 1 : capacity;
    final mats = List<int>.generate(safeCapacity, (index) => index + 1);
    final rowSize = safeCapacity <= 8
        ? 4
        : safeCapacity <= 15
            ? 5
            : 6;

    final rows = <List<int>>[];
    for (var i = 0; i < mats.length; i += rowSize) {
      rows.add(
        mats.sublist(
          i,
          (i + rowSize) > mats.length ? mats.length : i + rowSize,
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final gClass = widget.gymClass;
    final matRows = _buildMatRows(gClass.capacity);
    final selectedLabel = _selectedMat == null
        ? 'No mat selected'
        : 'Mat ${_selectedMat! + 1} selected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Spot'),
        backgroundColor: const Color(0xFF8A2BFF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2EBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8A2BFF), Color(0xFF2F7BFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gClass.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the yoga mat spot you want before confirming. ${gClass.filled}/${gClass.capacity} are already taken.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _LegendPill(
                          label: 'Available',
                          color: Color(0xFF69C27D),
                        ),
                        _LegendPill(
                          label: 'Selected',
                          color: Color(0xFF8A2BFF),
                        ),
                        _LegendPill(
                          label: 'Reserved',
                          color: Color(0xFFB8B8C4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.self_improvement, color: Color(0xFF6D37E6)),
                      SizedBox(width: 10),
                      Text(
                        'INSTRUCTOR FRONT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D37E6),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              StreamBuilder<Set<int>>(
                stream: DBReservations.getReservedMatNumbersStream(gClass.id),
                initialData: const <int>{},
                builder: (context, snapshot) {
                  final reservedMats = snapshot.data ?? <int>{};
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F2EA),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE7D8C8)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: matRows
                            .asMap()
                            .entries
                            .map(
                              (entry) => Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: entry.key.isEven ? 16 : 28,
                                  vertical: 10,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final rowCount = entry.value.length;
                                    const horizontalPaddingPerMat = 8.0;
                                    final availableWidth =
                                        constraints.maxWidth -
                                        (rowCount * horizontalPaddingPerMat);
                                    final maxTileWidth =
                                        availableWidth / rowCount;
                                    final tileWidth = maxTileWidth.clamp(
                                      32.0,
                                      54.0,
                                    );

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: entry.value.map((matNumber) {
                                        final index = matNumber - 1;
                                        final isReserved = reservedMats.contains(
                                          matNumber,
                                        );
                                        final isSelected = _selectedMat == index;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: SizedBox(
                                            width: tileWidth,
                                            child: AspectRatio(
                                              aspectRatio: 0.52,
                                              child: _YogaMatTile(
                                                number: matNumber,
                                                reserved: isReserved,
                                                selected: isSelected,
                                                onTap: isReserved
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _selectedMat = index;
                                                        });
                                                      },
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FB),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          selectedLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_selectedMat == null || _isSubmitting)
                              ? null
                              : () async {
                                  final matNumber = 'Mat #${_selectedMat! + 1}';
                                  setState(() => _isSubmitting = true);
                                  try {
                                    final reservedMat = await ref
                                        .read(reservationsProvider)
                                        .registerForClass(
                                          gClass,
                                          matNumber: matNumber,
                                        );
                                    if (!mounted || reservedMat == null) return;
                                    ref
                                        .read(providerGymClass)
                                        .applyLocalRegistrationDelta(gClass.id, 1);
                                    context.pushNamed(
                                      ReservationConfirmationScreen.routeName,
                                      extra: {
                                        'className': gClass.title,
                                        'instructor': gClass.instructor,
                                        'dateTime':
                                            '${gClass.dateText} at ${gClass.timeText}',
                                        'matNumber': reservedMat,
                                      },
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    var message = e.toString();
                                    if (message.startsWith('Exception: ')) {
                                      message = message.replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isSubmitting = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6200EE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _selectedMat == null
                                      ? 'Select a Mat'
                                      : 'Reserve Mat ${_selectedMat! + 1}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YogaMatTile extends StatelessWidget {
  final int number;
  final bool reserved;
  final bool selected;
  final VoidCallback? onTap;

  const _YogaMatTile({
    required this.number,
    required this.reserved,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = reserved
        ? const Color(0xFFADB0BA)
        : selected
            ? const Color(0xFF7C39F6)
            : const Color(0xFF4BAA72);
    final border = reserved
        ? const Color(0xFF8A8F9B)
        : selected
            ? const Color(0xFF5C1FD3)
            : const Color(0xFF2F8052);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x338A2BFF)
                  : const Color(0x12000000),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(fill, Colors.white, 0.10)!,
                      fill,
                      Color.lerp(fill, Colors.black, 0.12)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border, width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 16,
              right: 16,
              child: Container(
                height: 1.5,
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            if (reserved)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
