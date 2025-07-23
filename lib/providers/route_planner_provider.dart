import 'package:flutter/material.dart';
import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../services/hike_plan_service.dart';

class RoutePlannerProvider with ChangeNotifier {
  final HikePlanService _hikePlanService = HikePlanService();

  late HikePlan _originalPlan;
  late HikePlan _editablePlan;

  HikePlan get plan => _editablePlan;

  bool _hasChanges = false;
  bool get hasChanges => _hasChanges;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  void loadPlan(HikePlan planToLoad) {
    _originalPlan = planToLoad;
    _editablePlan = planToLoad.copyWith(
        dailyRoutes: planToLoad.dailyRoutes
            .map((r) => DailyRoute.fromFirestore(r.toFirestore()))
            .toList());
    _hasChanges = false;
    _isSaving = false;
    _ensureCorrectDayCount();
  }

  void _ensureCorrectDayCount() {
    int numberOfDays =
        (_editablePlan.endDate?.difference(_editablePlan.startDate).inDays ??
                0) +
            1;
    if (numberOfDays <= 0) numberOfDays = 1;

    final routes = _editablePlan.dailyRoutes;

    if (routes.length < numberOfDays) {
      for (int i = routes.length; i < numberOfDays; i++) {
        routes.add(DailyRoute(
            dayIndex: i,
            points: [],
            colorValue: kRouteColors[i % kRouteColors.length].value));
      }
    } else if (routes.length > numberOfDays) {
      _editablePlan =
          _editablePlan.copyWith(dailyRoutes: routes.sublist(0, numberOfDays));
    }
  }

  void updateRoutes(List<DailyRoute> newRoutes) {
    _editablePlan = _editablePlan.copyWith(dailyRoutes: newRoutes);
    _markAsChanged();
    notifyListeners();
  }

  void updateNoteForDay(int dayIndex, String note) {
    if (dayIndex < 0 || dayIndex >= _editablePlan.dailyRoutes.length) return;
    _editablePlan.dailyRoutes[dayIndex] =
        _editablePlan.dailyRoutes[dayIndex].copyWith(notes: note);
    _markAsChanged();
    // Ei tarvitse kutsua notifyListeners tässä, koska TextFormField hoitaa oman tilansa.
  }

  void updateColorForDay(int dayIndex, int colorValue) {
    if (dayIndex < 0 || dayIndex >= _editablePlan.dailyRoutes.length) return;
    _editablePlan.dailyRoutes[dayIndex] =
        _editablePlan.dailyRoutes[dayIndex].copyWith(colorValue: colorValue);
    _markAsChanged();
    notifyListeners();
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      _hasChanges = true;
      notifyListeners();
    }
  }

  Future<bool> saveChanges() async {
    if (!_hasChanges || _isSaving) return true;

    _isSaving = true;
    notifyListeners();

    try {
      await _hikePlanService.updateHikePlan(_editablePlan);
      _originalPlan = _editablePlan.copyWith();
      _hasChanges = false;
      return true;
    } catch (e) {
      print("Error saving plan: $e");
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  HikePlan getOriginalPlan() {
    return _originalPlan;
  }
}

const List<Color> kRouteColors = [
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.red,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
];
