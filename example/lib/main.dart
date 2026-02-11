import 'package:flutter/material.dart';

void main() {
  runApp(const FeedbackApp());
}

class FeedbackApp extends StatelessWidget {
  const FeedbackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feedback',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const FeedbackScreen(),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _submitted = false;
  String? _ratingError;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final ratingValid = _rating > 0;

    setState(() {
      _ratingError = ratingValid ? null : 'Please select a rating';
    });

    if (formValid && ratingValid) {
      setState(() => _submitted = true);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _commentController.clear();
    setState(() {
      _submitted = false;
      _rating = 0;
      _ratingError = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  // -- Success state ----------------------------------------------------------

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
          const SizedBox(height: 16),
          Text(
            'Thank you for your feedback!',
            key: const Key('success_message'),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$_rating star${_rating != 1 ? 's' : ''} from ${_nameController.text}',
            key: const Key('success_detail'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('reset_button'),
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            label: const Text('Send another'),
          ),
        ],
      ),
    );
  }

  // -- Form -------------------------------------------------------------------

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // Name
          TextFormField(
            key: const Key('name_field'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Rating
          Text('Rating', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            key: const Key('rating_row'),
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                key: Key('star_$star'),
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: star <= _rating ? Colors.amber : Colors.grey,
                  size: 36,
                ),
                onPressed: () => setState(() {
                  _rating = star;
                  _ratingError = null;
                }),
              );
            }),
          ),
          if (_ratingError != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _ratingError!,
                key: const Key('rating_error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Comment
          TextFormField(
            key: const Key('comment_field'),
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          // Submit
          FilledButton.icon(
            key: const Key('submit_button'),
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
