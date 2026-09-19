import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/barbershop_model.dart';

class FavoritesService {
  static const String _key = 'favorite_barbershops';

  static Future<List<int>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? ids = prefs.getStringList(_key);
    if (ids == null) return [];
    return ids.map((id) => int.parse(id)).toList();
  }

  static Future<bool> isFavorite(int barbershopId) async {
    final ids = await getFavoriteIds();
    return ids.contains(barbershopId);
  }

  static Future<void> toggleFavorite(int barbershopId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getFavoriteIds();
    
    if (ids.contains(barbershopId)) {
      ids.remove(barbershopId);
    } else {
      ids.add(barbershopId);
    }
    
    await prefs.setStringList(_key, ids.map((id) => id.toString()).toList());
  }

  static Future<List<Barbershop>> getFavoriteBarbershops(List<Barbershop> allBarbershops) async {
    final favoriteIds = await getFavoriteIds();
    return allBarbershops.where((shop) => favoriteIds.contains(shop.id)).toList();
  }
}
