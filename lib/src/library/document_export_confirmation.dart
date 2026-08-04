import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Confirms that the user intends to create a plaintext document copy.
Future<bool> confirmDocumentExport(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_open_outlined),
        title: Text(AppStrings.txtSaveAnUnencryptedCopy.tr),
        content: Text(
          AppStrings
              .txtTheSavedFileWillNoLongerBeProtectedByOwnKeepAnyoneWithAccessToTheSelectedDestinationMayBeAbleToOpenIt
              .tr,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.btnContinue.tr),
          ),
        ],
      ),
    ) ??
    false;
