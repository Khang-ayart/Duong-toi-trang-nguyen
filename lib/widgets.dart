import 'package:flutter/material.dart';

import 'theme.dart';

/// Khung giấy viền vàng dùng cho mọi khối nội dung.
class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderWidth = 1.4,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AppColors.gold,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> content = <Widget>[];
    if (icon != null) {
      content.add(Icon(icon, size: 20));
      content.add(const SizedBox(width: 8));
    }
    content.add(
      Flexible(
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: content,
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          side: const BorderSide(color: AppColors.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Trang căn giữa, cuộn được khi nội dung dài.
class PageScroll extends StatelessWidget {
  final List<Widget> children;

  const PageScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Dòng thống kê: nhãn bên trái, giá trị bên phải.
class StatRow extends StatelessWidget {
  final String label;
  final String value;

  const StatRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
