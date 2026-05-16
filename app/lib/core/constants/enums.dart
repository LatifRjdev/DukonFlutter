enum Currency { tjs, usd, rub }

enum StoreCategory { grocery, clothing, electronics, hardware, pharmacy, other }

enum ProductUnit { pcs, kg, l, m, pack }

extension CurrencyExtension on Currency {
  String get symbol {
    switch (this) {
      case Currency.tjs: return 'сом.';
      case Currency.usd: return '\$';
      case Currency.rub: return '₽';
    }
  }
}

extension StoreCategoryExtension on StoreCategory {
  String get displayName {
    switch (this) {
      case StoreCategory.grocery: return 'Продукты';
      case StoreCategory.clothing: return 'Одежда';
      case StoreCategory.electronics: return 'Электроника';
      case StoreCategory.hardware: return 'Стройматериалы';
      case StoreCategory.pharmacy: return 'Аптека';
      case StoreCategory.other: return 'Другое';
    }
  }
}

extension ProductUnitExtension on ProductUnit {
  String get displayName {
    switch (this) {
      case ProductUnit.pcs: return 'шт';
      case ProductUnit.kg: return 'кг';
      case ProductUnit.l: return 'л';
      case ProductUnit.m: return 'м';
      case ProductUnit.pack: return 'уп';
    }
  }
}
