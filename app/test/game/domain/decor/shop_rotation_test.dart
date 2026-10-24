import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/shop_rotation.dart';

void main() {
  final catalog = DecorCatalog.fromJson(
      jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>);
  final october23 = CalendarDay.parse('2026-10-23');
  final october24 = CalendarDay.parse('2026-10-24');

  test('the same day gives the same shop', () {
    final first = ShopRotation.forDay(catalog, october23).map((item) => item.id).toList();
    final second = ShopRotation.forDay(catalog, october23).map((item) => item.id).toList();
    expect(first, second);
  });

  test('six distinct purchasable items, the first one cheap', () {
    final shop = ShopRotation.forDay(catalog, october23);
    expect(shop, hasLength(Balance.shopSlotCount));
    expect(shop.map((item) => item.id).toSet(), hasLength(Balance.shopSlotCount));
    expect(shop.every((item) => catalog.shopPool.contains(item)), isTrue);
    expect(shop.first.priceGems, lessThanOrEqualTo(Balance.shopCheapMaxPriceGems));
  });

  test('different days usually differ', () {
    final days = [for (var day = 1; day <= 10; day++) CalendarDay.parse('2026-11-${day.toString().padLeft(2, '0')}')];
    final shops = {for (final day in days) ShopRotation.forDay(catalog, day).map((item) => item.id).join(',')};
    expect(shops.length, greaterThan(5));
  });

  test('a small pool returns what it has', () {
    final tiny = DecorCatalog.fromJson({
      'items': [
        {'id': 'plant', 'name': 'Plant', 'kind': 'furniture', 'rarity': 'common', 'price': 5, 'asset': 'furniture.plant.default.idle'},
      ],
    });
    expect(ShopRotation.forDay(tiny, october24).single.id, 'plant');
  });
}
