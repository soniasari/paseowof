class Validators {
  // Validar email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo electrónico es obligatorio';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  // Validar contraseña
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  // Validar CI boliviano (formato: 1234567 LP)
  static String? ci(String? value) {
    if (value == null || value.isEmpty) {
      return 'El CI es obligatorio';
    }
    final ciRegex = RegExp(r'^\d{5,8}\s[A-Z]{2}$');
    if (!ciRegex.hasMatch(value)) {
      return 'Formato inválido. Ejemplo: 1234567 LP';
    }
    return null;
  }

  // Validar CI solo números
  static String? ciNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'El CI es obligatorio';
    }
    final ciRegex = RegExp(r'^\d{5,8}$');
    if (!ciRegex.hasMatch(value)) {
      return 'El CI debe tener entre 5 y 8 dígitos';
    }
    return null;
  }

  // Validar campo requerido
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Este campo'} es obligatorio';
    }
    return null;
  }

  // Validar teléfono
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opcional
    }
    final phoneRegex = RegExp(r'^[0-9]{7,10}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''))) {
      return 'Ingresa un teléfono válido';
    }
    return null;
  }
}
