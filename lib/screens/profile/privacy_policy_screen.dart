import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'legal_content.dart';
import 'legal_document_view.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LegalDocumentView(
      title: l.privacyPolicyTitle,
      document: privacyDocument,
    );
  }
}
