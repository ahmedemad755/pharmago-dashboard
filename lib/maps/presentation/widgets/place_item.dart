import 'package:flutter/material.dart';
import 'package:fruitesdashboard/maps/data/models/placesugestion.dart';
class PlaceItem extends StatelessWidget {
  final PlaceSuggestion suggestion;

  const PlaceItem({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    // 1. تقسيم النص بناءً على أول فاصلة
    var parts = suggestion.description.split(',');
    
    // 2. الجزء الأول هو العنوان الرئيسي (مثلاً: "صيدلية الإسعاف")
    var title = parts[0]; 
    
    // 3. الجزء الثاني هو باقي العنوان (مثلاً: "وسط البلد، القاهرة")
    // بنشيل العنوان الرئيسي من النص الأصلي عشان نطلع الباقي بأمان
    var remainingText = parts.length > 1 
        ? suggestion.description.substring(title.length).trim() 
        : '';

    // 4. تنظيف النص الفرعي من أي فواصل في البداية
    if (remainingText.startsWith(',')) {
      remainingText = remainingText.substring(1).trim();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.all(8),
      padding: const EdgeInsetsDirectional.all(4),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle, 
            color: Colors.cyan,
          ),
          child: const Icon(
            Icons.place,
            color: Colors.blue,
          ),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              // عرض العنوان الرئيسي بخط عريض
              TextSpan(
                text: '$title\n',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              // عرض العنوان الفرعي لو موجود بخط أصغر ولون أفتح
              if (remainingText.isNotEmpty)
                TextSpan(
                  text: remainingText,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}