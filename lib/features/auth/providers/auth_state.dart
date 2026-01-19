import 'package:equatable/equatable.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';

/// Base class for authentication states.
///
/// States:
/// - [AuthStateUnauthenticated]: No user logged in
/// - [AuthStateLoading]: Performing an auth operation (generating/importing)
/// - [AuthStateAuthenticated]: User is logged in with a keypair
/// - [AuthStateError]: An error occurred during authentication
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// User is not authenticated.
class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();

  @override
  String toString() => 'AuthStateUnauthenticated';
}

/// Authentication operation in progress.
class AuthStateLoading extends AuthState {
  const AuthStateLoading({required this.operation});

  /// The operation being performed (e.g., 'generating', 'importing')
  final String operation;

  @override
  List<Object?> get props => [operation];

  @override
  String toString() => 'AuthStateLoading(operation: $operation)';
}

/// User is authenticated with a keypair.
class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated({
    required this.keypair,
    required this.nsec,
    required this.npub,
  });

  /// The user's keypair (private and public keys in hex format)
  final KeyPair keypair;

  /// The private key in nsec format (bech32)
  final String nsec;

  /// The public key in npub format (bech32)
  final String npub;

  @override
  List<Object?> get props => [keypair, nsec, npub];

  @override
  String toString() => 'AuthStateAuthenticated(npub: $npub)';
}

/// An error occurred during authentication.
class AuthStateError extends AuthState {
  const AuthStateError({required this.message, this.previousState});

  /// Error message
  final String message;

  /// The state before the error occurred (for retry/recovery)
  final AuthState? previousState;

  @override
  List<Object?> get props => [message, previousState];

  @override
  String toString() => 'AuthStateError(message: $message)';
}
