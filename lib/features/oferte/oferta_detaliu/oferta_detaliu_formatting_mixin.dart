import 'package:flutter/material.dart';

import '../offer_currency_converter.dart';
import '../offer_models.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Metode pure de formatare dată/bani/valută pentru [OfertaDetaliuPage].
///
/// Fără I/O, fără side-effects — depind exclusiv de câmpul [offer] (starea
/// curentă a ofertei), furnizat de clasa care aplică acest mixin.
mixin OffertaDetaliuFormattingMixin on State<OfertaDetaliuPage> {
  OfferRecord get offer;

  String formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String moneyCommercial(double ronAmount) {
    return OfferCurrencyConverter.formatMoney(
      ronAmount: ronAmount,
      currency: offer.currency,
      effectiveRate: offer.effectiveExchangeRate,
    );
  }

  OfferPriceDisplayMode get priceDisplayMode => offer.priceDisplayMode;

  double get vatMultiplier => 1 + (offer.vatPercent / 100);

  double amountWithVat(double amountWithoutVat) {
    return amountWithoutVat * vatMultiplier;
  }

  String priceDisplayModeLabel() => priceDisplayMode.label;

  String priceDisplayExplanation() {
    switch (priceDisplayMode) {
      case OfferPriceDisplayMode.withoutVat:
        return 'Prețurile sunt exprimate fără TVA.';
      case OfferPriceDisplayMode.withVat:
        return 'Prețurile sunt exprimate cu TVA inclus.';
      case OfferPriceDisplayMode.both:
        return 'Prețurile sunt afișate atât fără TVA, cât și cu TVA.';
    }
  }

  String displayAmount(double amountWithoutVat) {
    final withoutVat = moneyCommercial(amountWithoutVat);
    final withVat = moneyCommercial(amountWithVat(amountWithoutVat));
    switch (priceDisplayMode) {
      case OfferPriceDisplayMode.withoutVat:
        return withoutVat;
      case OfferPriceDisplayMode.withVat:
        return withVat;
      case OfferPriceDisplayMode.both:
        return '$withoutVat fără TVA | $withVat cu TVA';
    }
  }

  String displaySingleAmount(double amountWithoutVat) {
    final withoutVat = moneyCommercial(amountWithoutVat);
    final withVat = moneyCommercial(amountWithVat(amountWithoutVat));
    switch (priceDisplayMode) {
      case OfferPriceDisplayMode.withoutVat:
        return withoutVat;
      case OfferPriceDisplayMode.withVat:
        return withVat;
      case OfferPriceDisplayMode.both:
        return '$withoutVat | $withVat';
    }
  }

  String displayAmountWithLabels(
    double amountWithoutVat, {
    String withoutVatLabel = 'Fără TVA',
    String withVatLabel = 'Cu TVA',
  }) {
    final withoutVat = moneyCommercial(amountWithoutVat);
    final withVat = moneyCommercial(amountWithVat(amountWithoutVat));
    switch (priceDisplayMode) {
      case OfferPriceDisplayMode.withoutVat:
        return withoutVat;
      case OfferPriceDisplayMode.withVat:
        return withVat;
      case OfferPriceDisplayMode.both:
        return '$withoutVatLabel: $withoutVat | $withVatLabel: $withVat';
    }
  }

  String rateLabel() {
    final currency = OfferCurrencyConverter.normalizeCurrency(offer.currency);
    if (!OfferCurrencyConverter.requiresRate(currency)) return '-';
    final base = offer.exchangeRateSource == OfferExchangeRateSource.bnr
        ? offer.bnrRate
        : offer.manualRate;
    final source = offer.exchangeRateSource.label;
    final commission = offer.exchangeCommissionPercent.toStringAsFixed(2);
    final effective = offer.effectiveExchangeRate > 0
        ? offer.effectiveExchangeRate.toStringAsFixed(4)
        : '-';
    final baseLabel = base > 0 ? base.toStringAsFixed(4) : '-';
    return '$source | baza $baseLabel | comision $commission% | efectiv $effective';
  }
}
