/// Usuario con sesión iniciada. El dominio no depende de Firebase (design.md §1).
class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}
