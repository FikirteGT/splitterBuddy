class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}

class WorkspaceException extends AppException {
  const WorkspaceException(super.message, [super.code]);
}

class ExpenseException extends AppException {
  const ExpenseException(super.message, [super.code]);
}

class SettlementException extends AppException {
  const SettlementException(super.message, [super.code]);
}

class PermissionException extends AppException {
  const PermissionException([String message = 'You do not have permission to perform this action.'])
      : super(message, 'permission-denied');
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.code]);
}
