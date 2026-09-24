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
}

const String waterJarImg = "assets/icons/water_jar.svg";
const String waterBottleImg = "assets/icons/water_bottle.svg";

const List<ProductModel> demoPopularProducts = [
  ProductModel(
    id: "wd-20l",
    image: waterJarImg,
    brandName: "20 Litres",
    title: "20L Drinking Water Jar",
    price: 60,
    capacity: "20 Litres",
    unit: "jar",
    container: "Reusable Water Jar",
  ),
  ProductModel(
    id: "wd-15l",
    image: waterJarImg,
    brandName: "15 Litres",
    title: "15L Drinking Water Can",
    price: 50,
    capacity: "15 Litres",
    unit: "can",
    container: "Reusable Water Can",
  ),
  ProductModel(
    id: "wd-10l",
    image: waterJarImg,
    brandName: "10 Litres",
    title: "10L Drinking Water Can",
    price: 40,
    capacity: "10 Litres",
    unit: "can",
    container: "Reusable Water Can",
  ),
  ProductModel(
    id: "wd-1l-12",
    image: waterBottleImg,
    brandName: "12 Litres",
    title: "1L Bottles · Pack of 12",
    price: 120,
    capacity: "12 × 1 Litre",
    unit: "pack",
    container: "PET Bottles",
  ),
  ProductModel(
    id: "wd-500ml-12",
    image: waterBottleImg,
    brandName: "6 Litres",
    title: "500ml Bottles · Pack of 12",
    price: 90,
    capacity: "12 × 500 ml",
    unit: "pack",
    container: "PET Bottles",
  ),
  ProductModel(
    id: "wd-5l",
    image: waterJarImg,
    brandName: "5 Litres",
    title: "5L Drinking Water Can",
    price: 35,
    capacity: "5 Litres",
    unit: "can",
    container: "Reusable Water Can",
  ),
];

final List<ProductModel> demoFlashSaleProducts = [
  demoPopularProducts[0],
  demoPopularProducts[1],
  demoPopularProducts[2],
];

final List<ProductModel> demoBestSellersProducts = [
  demoPopularProducts[0],
  demoPopularProducts[3],
  demoPopularProducts[4],
];

final List<ProductModel> kidsProducts = [
  demoPopularProducts[4],
  demoPopularProducts[3],
  demoPopularProducts[5],
];
