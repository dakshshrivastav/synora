import 'dart:convert';

/// Validated meal-level totals. Model uncertainty is qualitative, not calibrated.
class MealEstimate {
  const MealEstimate._({
    required this.title,
    required this.foods,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.assumptions,
    required this.uncertainty,
  });

  final String title, portion, uncertainty;
  final List<String> foods, assumptions;
  final double calories, protein, carbs, fat;

  factory MealEstimate.parse(String content) {
    if (content.length > 16000) {
      throw const FormatException('Meal estimate was too long.');
    }
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Expected a meal estimate object.');
    }
    return MealEstimate.fromJson(json);
  }

  factory MealEstimate.fromJson(Map<String, dynamic> json) {
    if (json['food_visible'] == false) {
      throw const FormatException(
        'No identifiable food in this photo. Try a clearer photo and caption.',
      );
    }
    if (json['food_visible'] != true) {
      throw const FormatException(
        'The model did not identify whether food is visible.',
      );
    }
    String text(String key, int max) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > max) {
        throw FormatException('Invalid $key in meal estimate.');
      }
      return value.trim();
    }

    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0 || value > 20000) {
        throw FormatException('Invalid $key in meal estimate.');
      }
      return value.toDouble();
    }

    List<String> strings(String key, {required int min}) {
      final value = json[key];
      if (value is! List ||
          value.length < min ||
          value.length > 20 ||
          value.any(
            (v) => v is! String || v.trim().isEmpty || v.length > 300,
          )) {
        throw FormatException('Invalid $key in meal estimate.');
      }
      return List.unmodifiable(value.cast<String>().map((v) => v.trim()));
    }

    final uncertainty = text('uncertainty', 10);
    if (!['low', 'medium', 'high'].contains(uncertainty)) {
      throw const FormatException('Invalid estimate uncertainty.');
    }
    return MealEstimate._(
      title: text('title', 200),
      foods: strings('foods', min: 1),
      portion: text('portion', 500),
      calories: number('calories'),
      protein: number('protein'),
      carbs: number('carbs'),
      fat: number('fat'),
      assumptions: strings('assumptions', min: 0),
      uncertainty: uncertainty,
    );
  }

  Map<String, dynamic> toJson() => {
    'food_visible': true,
    'title': title,
    'foods': foods,
    'portion': portion,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'assumptions': assumptions,
    'uncertainty': uncertainty,
  };
}

const mealEstimateSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'food_visible': {'type': 'boolean'},
    'title': {'type': 'string'},
    'foods': {
      'type': 'array',
      'items': {'type': 'string'},
      'maxItems': 20,
    },
    'portion': {'type': 'string'},
    'calories': {'type': 'number', 'minimum': 0, 'maximum': 20000},
    'protein': {'type': 'number', 'minimum': 0, 'maximum': 20000},
    'carbs': {'type': 'number', 'minimum': 0, 'maximum': 20000},
    'fat': {'type': 'number', 'minimum': 0, 'maximum': 20000},
    'assumptions': {
      'type': 'array',
      'items': {'type': 'string'},
      'maxItems': 20,
    },
    'uncertainty': {
      'type': 'string',
      'enum': ['low', 'medium', 'high'],
    },
  },
  'required': [
    'food_visible',
    'title',
    'foods',
    'portion',
    'calories',
    'protein',
    'carbs',
    'fat',
    'assumptions',
    'uncertainty',
  ],
};
