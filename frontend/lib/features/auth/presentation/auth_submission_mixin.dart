import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:flutter/material.dart';

mixin AuthSubmissionMixin<T extends StatefulWidget> on State<T> {
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  Future<void> submitAuthAction<R>({
    required Future<R> Function() action,
    required void Function(R? result) onSuccess,
    String genericErrorMessage = 'Não foi possível concluir a operação.',
    bool ignoreFailures = false,
  }) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await action();
      if (!mounted) {
        return;
      }

      onSuccess(result);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (ignoreFailures) {
        onSuccess(null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (ignoreFailures) {
        onSuccess(null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(genericErrorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
