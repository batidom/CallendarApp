import 'package:flutter/material.dart';

/// Search-then-pick dialog: a text field + search button, results listed
/// below, tap one to return it via Navigator.pop (or null if dismissed).
/// A plain search-on-submit rather than live-as-you-type, since [search]
/// hits a network API and there's no need to fire it on every keystroke for
/// a one-off settings pick. Shared by Settings' weather-city and
/// home-address pickers so neither reimplements the same
/// search/loading/error/results UI.
class SearchPickerDialog<T> extends StatefulWidget {
  const SearchPickerDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.noResultsText,
    required this.errorText,
    required this.search,
    required this.labelBuilder,
  });

  final String title;
  final String hintText;
  final String noResultsText;
  final String errorText;
  final Future<List<T>> Function(String query) search;
  final String Function(T result) labelBuilder;

  @override
  State<SearchPickerDialog<T>> createState() => _SearchPickerDialogState<T>();
}

class _SearchPickerDialogState<T> extends State<SearchPickerDialog<T>> {
  final _controller = TextEditingController();
  List<T>? _results;
  bool _loading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final results = await widget.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hintText,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(widget.errorText, style: const TextStyle(color: Colors.red)),
              )
            else if (_results != null)
              _results!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        widget.noResultsText,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results!.length,
                        itemBuilder: (context, index) {
                          final result = _results![index];
                          return ListTile(
                            dense: true,
                            title: Text(widget.labelBuilder(result)),
                            onTap: () => Navigator.of(context).pop(result),
                          );
                        },
                      ),
                    ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
