// Water catalog. Field names kept for compat with existing widgets;
// brandName carries the capacity label (e.g. "20 LITRES").
class ProductModel {
  final String id, image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;
  final String capacity;
  final String unit;
  final String container;
  final String waterType;
  final bool available;

  const ProductModel({
    required this.id,
    required this.image,
    required this.brandName,
    required this.title,
    required this.price,
    this.priceAfetDiscount,
    this.dicountpercent,
    required this.capacity,
    required this.unit,
    required this.container,
    this.waterType = "Drinking Water",
    this.available = true,
  });

  String get priceLabel => "₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}";

  /// Parses the backend product shape:
  /// `{id,name,capacity,unit,container,water_type,price,image,available}`.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final unit = json['unit']?.toString() ?? 'jar';
    final rawAvailable = json['available'];
    final available = rawAvailable is bool
        ? rawAvailable
        : rawAvailable is num
            ? rawAvailable != 0
            : true;
    return ProductModel(
      id: json['id']?.toString() ?? '',
      image: json['image']?.toString() ??
          (unit == 'pack' ? waterBottleImg : waterJarImg),
      brandName: json['capacity']?.toString() ??
          json['brandName']?.toString() ??
          unit,
      title: json['name']?.toString() ?? json['title']?.toString() ?? unit,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      capacity: json['capacity']?.toString() ?? '',
      unit: unit,
      container: json['container']?.toString() ?? '',
      waterType: json['water_type']?.toString() ??
          json['waterType']?.toString() ??
          'Drinking Water',
      available: available,
    );
  }
}

const String waterJarImg = "assets/images/jar_20l.jpg";
const String waterBottleImg = "assets/images/bottle_1l.png";

const List<ProductModel> demoPopularProducts = [
  ProductModel(
    id: "wd-20l-refill",
    image: waterJarImg,
    brandName: "20 Litres",
    title: "20L Water Refill (Own Container)",
    price: 28,
    capacity: "20 Litres",
    unit: "refill",
    container: "Your Own Container",
  ),
  ProductModel(
    id: "wd-20l-jar",
    image: "assets/images/jar_20l_container.png",
    brandName: "20 Litres",
    title: "20L Jar with Container",
    price: 30,
    capacity: "20 Litres",
    unit: "jar",
    container: "Jar with Tap",
  ),
  ProductModel(
    id: "wd-1l",
    image: waterBottleImg,
    brandName: "1 Litre",
    title: "1L Water Bottle",
    price: 0,
    capacity: "1 Litre",
    unit: "bottle",
    container: "PET Bottle",
    available: false,
  ),
];

final List<ProductModel> demoFlashSaleProducts = [
  demoPopularProducts[0],
  demoPopularProducts[1],
  demoPopularProducts[2],
];

final List<ProductModel> demoBestSellersProducts = [
  demoPopularProducts[0],
  demoPopularProducts[1],
  demoPopularProducts[2],
];

final List<ProductModel> kidsProducts = [
  demoPopularProducts[0],
  demoPopularProducts[1],
  demoPopularProducts[2],
];
