import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_model.dart';

class CardService {
  static const String _collectedCardsKey = 'collected_cards';

  Future<List<CardModel>> getCollectedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cardsJson = prefs.getString(_collectedCardsKey);
    if (cardsJson == null) return [];

    final List<dynamic> cardsList = json.decode(cardsJson);
    return cardsList.map((card) => CardModel.fromJson(card)).toList();
  }

  Future<void> collectCard(CardModel card) async {
    final prefs = await SharedPreferences.getInstance();
    final List<CardModel> currentCards = await getCollectedCards();
    
    // Check if card already exists
    if (currentCards.any((c) => c.id == card.id)) return;
    
    currentCards.add(card);
    final String cardsJson = json.encode(currentCards.map((c) => c.toJson()).toList());
    await prefs.setString(_collectedCardsKey, cardsJson);
  }

  Future<void> removeCard(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<CardModel> currentCards = await getCollectedCards();
    
    currentCards.removeWhere((card) => card.id == cardId);
    final String cardsJson = json.encode(currentCards.map((c) => c.toJson()).toList());
    await prefs.setString(_collectedCardsKey, cardsJson);
  }
} 