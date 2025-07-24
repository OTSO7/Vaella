// lib/utils/rating_utils.dart

import 'package:flutter/material.dart';

// Määritellään vakiot arvostelujen tyypeille
class RatingType {
  static const String weather = 'weather';
  static const String difficulty = 'difficulty';
  static const String experience = 'experience';
}

// SÄÄ: Selkeä asteikko huonosta erinomaiseen
const Map<int, String> weatherRatingLabels = {
  1: 'Very Poor',
  2: 'Poor',
  3: 'Fair', // "Kohtalainen" tai "OK", mutta ammattimaisempi
  4: 'Good',
  5: 'Excellent',
};

// VAIKEUSASTE: Yleisesti käytetty terminologia
const Map<int, String> difficultyRatingLabels = {
  1: 'Very Easy',
  2: 'Easy',
  3: 'Moderate', // "Medium" on OK, mutta "Moderate" on yleisempi standardi
  4: 'Hard',
  5: 'Very Hard', // Selkeämpi ja vähemmän dramaattinen kuin "Extremely hard"
};

// KOKEMUS: Suora ja johdonmukainen arviointiasteikko
const Map<int, String> experienceRatingLabels = {
  1: 'Very Bad',
  2: 'Bad',
  3: 'Average', // Parempi ja selkeämpi kuin "OK" tai "Nothing special"
  4: 'Good',
  5: 'Excellent',
};

// Apufunktio, pidetään otsikot myös ytimekkäinä
Map<String, dynamic> getRatingData(String ratingType) {
  switch (ratingType) {
    case RatingType.weather:
      return {
        'title': 'Weather Conditions', // Sääolosuhteet
        'icon': Icons.wb_sunny_outlined,
        'labels': weatherRatingLabels,
      };
    case RatingType.difficulty:
      return {
        'title': 'Hike Difficulty', // Reitin vaikeusaste
        'icon': Icons.terrain_outlined,
        'labels': difficultyRatingLabels,
      };
    case RatingType.experience:
    default:
      return {
        'title': 'Overall Experience', // Kokonaiskokemus
        'icon': Icons.sentiment_very_satisfied_outlined,
        'labels': experienceRatingLabels,
      };
  }
}
