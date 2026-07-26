class Profile {
  final String name;
  final String email;
  final String phone;
  final String bio;

  Profile({
    this.name = 'Your Name',
    this.email = 'you@example.com',
    this.phone = '0000000000',
    this.bio = 'Offline profile details stored locally.',
  });

  Profile copyWith({
    String? name,
    String? email,
    String? phone,
    String? bio,
  }) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      name: map['name'] ?? 'Your Name',
      email: map['email'] ?? 'you@example.com',
      phone: map['phone'] ?? '0000000000',
      bio: map['bio'] ?? 'Offline profile details stored locally.',
    );
  }
}
