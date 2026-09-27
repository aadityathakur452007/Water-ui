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
  CategoryModel(title: "20L Refill", svgSrc: "assets/icons/water_jar.svg"),
  CategoryModel(title: "20L Jar", svgSrc: "assets/icons/water_jar.svg"),
  CategoryModel(title: "1L Bottle", svgSrc: "assets/icons/water_bottle.svg"),
];

final List<CategoryModel> demoCategories = [
  CategoryModel(
    title: "Refills",
    svgSrc: "assets/icons/water_jar.svg",
    subCategories: [
      CategoryModel(title: "20L Water Refill (Own Container)"),
    ],
  ),
  CategoryModel(
    title: "Water Jars",
    svgSrc: "assets/icons/water_jar.svg",
    subCategories: [
      CategoryModel(title: "20L Jar with Container"),
    ],
  ),
  CategoryModel(
    title: "Water Bottles",
    svgSrc: "assets/icons/water_bottle.svg",
    subCategories: [
      CategoryModel(title: "1L Water Bottle"),
    ],
  ),
];
