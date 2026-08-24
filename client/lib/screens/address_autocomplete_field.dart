import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/address_service.dart';

/// A text field that suggests real street addresses as the user types, via
/// [AddressService] (Photon/OpenStreetMap). [biasLatitude]/[biasLongitude],
/// when given, nudge ranking toward that area — street names commonly
/// repeat across a country, so without a bias point a query like
/// "Kazimierza" can't tell which town's street the user means.
///
/// Deliberately debounced (unlike the friend-search field in
/// social_screen.dart, which queries our own backend on every keystroke):
/// this hits a free public third-party API, so firing a request per
/// keystroke would be both wasteful and prone to results arriving out of
/// typing order.
class AddressAutocompleteField extends ConsumerStatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.biasLatitude,
    this.biasLongitude,
  });

  final TextEditingController controller;
  final String labelText;
  final double? biasLatitude;
  final double? biasLongitude;

  @override
  ConsumerState<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends ConsumerState<AddressAutocompleteField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<AddressResult>? _results;
  // Bumped on every new search; a response is only applied if it's still
  // the most recent one, so a slow early keystroke's result can't clobber
  // a faster later one's.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) setState(() => _results = null);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    List<AddressResult> results;
    try {
      results = await ref.read(addressServiceProvider).search(
            query,
            biasLatitude: widget.biasLatitude,
            biasLongitude: widget.biasLongitude,
          );
    } catch (_) {
      results = const [];
    }
    if (!mounted || requestId != _requestId) return;
    setState(() => _results = results);
  }

  void _select(AddressResult result) {
    widget.controller.text = result.displayName;
    setState(() => _results = null);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
          ),
          onChanged: _onChanged,
        ),
        if (results != null && results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18),
                    title: Text(result.displayName, style: const TextStyle(fontSize: 13)),
                    onTap: () => _select(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
