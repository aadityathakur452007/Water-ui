class CategoryModel {
  final String title;
  final String? image, svgSrc;
  final List<CategoryModel>? subCategories;

  CategoryModel({
    required this.title,
    this.image,
    this.svgSrc,
    this.subCategories,
  });
}

final List<CategoryModel> demoCategoriesWithImage = [
  CategoryModel(title: "20L Jar", svgSrc: "assets/icons/water_jar.svg"),
  CategoryModel(title: "15L Can", svgSrc: "assets/icons/water_jar.svg"),
  CategoryModel(title: "10L Can", svgSrc: "assets/icons/water_jar.svg"),
  CategoryModel(title: "1L Bottle", svgSrc: "assets/icons/water_bottle.svg"),
  CategoryModel(title: "500ml Bottle", svgSrc: "assets/icons/water_bottle.svg"),
];

final List<CategoryModel> demoCategories = [
  CategoryModel(
    title: "Water Jars",
    svgSrc: "assets/icons/water_jar.svg",
    subCategories: [
      CategoryModel(title: "20L Drinking Water Jar"),
      CategoryModel(title: "Refill / Exchange"),
    ],
  ),
  CategoryModel(
    title: "Water Cans",
    svgSrc: "assets/icons/water_jar.svg",
    subCategories: [
      CategoryModel(title: "15L Drinking Water Can"),
      CategoryModel(title: "10L Drinking Water Can"),
      CategoryModel(title: "5L Drinking Water Can"),
    ],
  ),
  CategoryModel(
    title: "Water Bottles",
    svgSrc: "assets/icons/water_bottle.svg",
    subCategories: [
      CategoryModel(title: "1L Bottles · Pack of 12"),
      CategoryModel(title: "500ml Bottles · Pack of 12"),
    ],
  ),
  CategoryModel(
    title: "Packaged Water",
    svgSrc: "assets/icons/Product.svg",
    subCategories: [
      CategoryModel(title: "Bulk / Event Packs"),
    ],
  ),
];
