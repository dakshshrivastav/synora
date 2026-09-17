import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freon/data/meal_estimate.dart';

const validEstimate = <String, dynamic>{
  'food_visible': true,
  'title': 'Rice and chicken',
  'foods': ['Rice', 'Chicken'],
  'portion': 'One cup rice and 120 g chicken; entire serving eaten',
  'calories': 520,
  'protein': 38,
  'carbs': 55,
  'fat': 15,
  'assumptions': ['One teaspoon of cooking oil, as stated in the caption'],
  'uncertainty': 'medium',
};

void main() {
  test('validates meal totals and preserves portion assumptions', () {
    final estimate = MealEstimate.parse(jsonEncode(validEstimate));
    expect(estimate.calories, 520);
    expect(estimate.foods, ['Rice', 'Chicken']);
    expect(estimate.toJson(), validEstimate);
  });

  for (final bad in [
    '520 kcal',
    null,
    -1,
    double.infinity,
    double.nan,
    20001,
  ]) {
    test('rejects invalid numeric totals: $bad', () {
      expect(
        () => MealEstimate.fromJson({...validEstimate, 'calories': bad}),
        throwsFormatException,
      );
    });
  }
  test('rejects non-food photos instead of logging zero calorie meals', () {
    expect(
      () => MealEstimate.fromJson({...validEstimate, 'food_visible': false}),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('No identifiable food'),
        ),
      ),
    );
  });
  test('rejects missing fields, invalid lists and prose', () {
    expect(
      () => MealEstimate.fromJson({...validEstimate}..remove('portion')),
      throwsFormatException,
    );
    expect(
      () => MealEstimate.fromJson({
        ...validEstimate,
        'foods': [123],
      }),
      throwsFormatException,
    );
    expect(
      () => MealEstimate.parse('Here is what I think you ate…'),
      throwsFormatException,
    );
  });
}
