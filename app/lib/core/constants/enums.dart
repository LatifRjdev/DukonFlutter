import 'package:dukonpro/l10n/app_localizations.dart';

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
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case StoreCategory.grocery: return l10n.grocery;
      case StoreCategory.clothing: return l10n.clothing;
      case StoreCategory.electronics: return l10n.electronics;
      case StoreCategory.hardware: return l10n.hardware;
      case StoreCategory.pharmacy: return l10n.pharmacy;
      case StoreCategory.other: return l10n.other;
    }
  }
}

extension ProductUnitExtension on ProductUnit {
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ProductUnit.pcs: return l10n.pcs;
      case ProductUnit.kg: return l10n.kg;
      case ProductUnit.l: return l10n.liter;
      case ProductUnit.m: return l10n.meter;
      case ProductUnit.pack: return l10n.pack;
    }
  }
}
