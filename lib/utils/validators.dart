class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingrese su correo electrónico';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Por favor ingrese un correo electrónico válido';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }

    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres para cuentas clínicas';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe combinar letras y números';
    }

    return null;
  }

  /// Sanitiza números de teléfono para su uso seguro en esquemas de mensajería (wa.me, tel:)
  static String sanitizePhone(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Limpia texto eliminando caracteres de control no imprimibles
  static String sanitizeText(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
  }
}

