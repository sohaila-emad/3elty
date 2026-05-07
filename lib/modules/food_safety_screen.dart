import 'package:flutter/material.dart';
import '../main.dart';

enum _FoodStatus { safe, danger, forbidden }

class _FoodItem {
  final String name;
  final String description;
  final String emoji;
  final _FoodStatus status;

  const _FoodItem({
    required this.name,
    required this.description,
    required this.emoji,
    required this.status,
  });
}

const _allFoods = [
  _FoodItem(
    name: 'ملوخية',
    description: 'غنية بالحديد والفيتامينات، مفيدة جداً للحامل',
    emoji: '🥬',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'عدس',
    description: 'مصدر ممتاز للبروتين النباتي وحمض الفوليك',
    emoji: '🌿',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'موز',
    description: 'يساعد على تخفيف الغثيان ومصدر جيد للبوتاسيوم',
    emoji: '🍌',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'لبن كامل الدسم',
    description: 'مصدر ممتاز للكالسيوم وفيتامين د لنمو العظام',
    emoji: '🥛',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'بيض مطبوخ جيداً',
    description: 'غني بالبروتين والكولين المهم لنمو دماغ الجنين',
    emoji: '🥚',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'جزر',
    description: 'غني بالبيتا كاروتين وفيتامين أ لصحة الجنين',
    emoji: '🥕',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'سمك سلمون',
    description: 'غني بأوميجا 3 المهمة لتطور مخ الجنين',
    emoji: '🐟',
    status: _FoodStatus.safe,
  ),
  _FoodItem(
    name: 'كبدة',
    description: 'تحتوي على نسبة عالية من فيتامين أ قد تضر الجنين',
    emoji: '🫀',
    status: _FoodStatus.danger,
  ),
  _FoodItem(
    name: 'تونة معلبة كثيراً',
    description: 'نسبة الزئبق قد ترتفع عند الإفراط في تناولها',
    emoji: '🐡',
    status: _FoodStatus.danger,
  ),
  _FoodItem(
    name: 'قهوة كثيرة',
    description: 'الكافيين الزائد يؤثر على نمو الجنين، حدّدي كوباً يومياً',
    emoji: '☕',
    status: _FoodStatus.danger,
  ),
  _FoodItem(
    name: 'جبن غير بستر',
    description: 'قد يحتوي على بكتيريا الليستيريا الخطرة على الحمل',
    emoji: '🧀',
    status: _FoodStatus.forbidden,
  ),
  _FoodItem(
    name: 'سوشي نيء',
    description: 'السمك النيء يحمل خطر طفيليات وبكتيريا ضارة',
    emoji: '🍣',
    status: _FoodStatus.forbidden,
  ),
  _FoodItem(
    name: 'بيض نيء',
    description: 'خطر السالمونيلا والبكتيريا الضارة للأم والجنين',
    emoji: '🥚',
    status: _FoodStatus.forbidden,
  ),
  _FoodItem(
    name: 'كحول',
    description: 'ممنوع تماماً — يؤثر خطيراً على تطور الجنين',
    emoji: '🚫',
    status: _FoodStatus.forbidden,
  ),
  _FoodItem(
    name: 'لحم نيء أو نصف مطبوخ',
    description: 'خطر التوكسوبلازما والليستيريا الضارة للجنين',
    emoji: '🥩',
    status: _FoodStatus.forbidden,
  ),
];

class FoodSafetyScreen extends StatefulWidget {
  const FoodSafetyScreen({super.key});

  @override
  State<FoodSafetyScreen> createState() => _FoodSafetyScreenState();
}

class _FoodSafetyScreenState extends State<FoodSafetyScreen> {
  _FoodStatus? _filter; // null = الكل
  String _search = '';

  static const _pink = Color(0xFFAD1457);

  List<_FoodItem> get _filtered {
    return _allFoods.where((f) {
      final matchStatus = _filter == null || f.status == _filter;
      final matchSearch = _search.isEmpty ||
          f.name.contains(_search) ||
          f.description.contains(_search);
      return matchStatus && matchSearch;
    }).toList();
  }

  Color _statusColor(_FoodStatus s) {
    switch (s) {
      case _FoodStatus.safe:      return const Color(0xFF2E7D32);
      case _FoodStatus.danger:    return const Color(0xFFE65100);
      case _FoodStatus.forbidden: return const Color(0xFFC62828);
    }
  }

  Color _statusBg(_FoodStatus s) {
    switch (s) {
      case _FoodStatus.safe:      return const Color(0xFFE8F5E9);
      case _FoodStatus.danger:    return const Color(0xFFFFF3E0);
      case _FoodStatus.forbidden: return const Color(0xFFFFEBEE);
    }
  }

  IconData _statusIcon(_FoodStatus s) {
    switch (s) {
      case _FoodStatus.safe:      return Icons.check_circle_rounded;
      case _FoodStatus.danger:    return Icons.warning_amber_rounded;
      case _FoodStatus.forbidden: return Icons.cancel_rounded;
    }
  }

  String _statusLabel(_FoodStatus s) {
    switch (s) {
      case _FoodStatus.safe:      return 'آمن';
      case _FoodStatus.danger:    return 'خطر';
      case _FoodStatus.forbidden: return 'ممنوع';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: _pink,
            foregroundColor: Colors.white,
            title: const Text('متابعة الحمل',
                style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── هيدر ──────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFAD1457), Color(0xFFC2185B)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('🍴',
                          style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('دليل الأغذية الآمنة',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          SizedBox(height: 4),
                          Text('صحتك وصحة طفلك تبدأ من طبقك اليومي',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ]),
                ),

                // ── سيرش ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'ابحثي عن أكل...',
                      hintStyle:
                          const TextStyle(color: AppColors.grey400),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.grey400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── فلاتر ─────────────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: _filter == null,
                      color: _pink,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'آمن',
                      selected: _filter == _FoodStatus.safe,
                      color: const Color(0xFF2E7D32),
                      onTap: () => setState(() =>
                          _filter = _filter == _FoodStatus.safe
                              ? null
                              : _FoodStatus.safe),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'تحذير',
                      selected: _filter == _FoodStatus.danger,
                      color: const Color(0xFFE65100),
                      onTap: () => setState(() =>
                          _filter = _filter == _FoodStatus.danger
                              ? null
                              : _FoodStatus.danger),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'ممنوع',
                      selected: _filter == _FoodStatus.forbidden,
                      color: const Color(0xFFC62828),
                      onTap: () => setState(() =>
                          _filter = _filter == _FoodStatus.forbidden
                              ? null
                              : _FoodStatus.forbidden),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── الجريد ────────────────────────────────────────────────
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('لا توجد نتائج',
                          style: TextStyle(
                              fontSize: 16, color: AppColors.grey500)),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final f = items[i];
                      return _FoodCard(
                        food: f,
                        statusColor: _statusColor(f.status),
                        statusBg: _statusBg(f.status),
                        statusIcon: _statusIcon(f.status),
                        statusLabel: _statusLabel(f.status),
                      );
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip فلتر ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.grey200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.grey600,
          ),
        ),
      ),
    );
  }
}

// ── بطاقة الأكلة ─────────────────────────────────────────────────────────────
class _FoodCard extends StatelessWidget {
  final _FoodItem food;
  final Color statusColor;
  final Color statusBg;
  final IconData statusIcon;
  final String statusLabel;

  const _FoodCard({
    required this.food,
    required this.statusColor,
    required this.statusBg,
    required this.statusIcon,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // badge الحالة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: statusColor, size: 12),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ]),
              ),
            ],
          ),

          const Spacer(),

          // إيموجي
          Center(
            child: Text(food.emoji,
                style: const TextStyle(fontSize: 40)),
          ),

          const Spacer(),

          // الاسم
          Text(
            food.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.grey900,
            ),
          ),

          const SizedBox(height: 4),

          // الوصف
          Text(
            food.description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.grey500,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}