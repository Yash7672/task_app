class Profile {
  final String name;
  final String email;
  final String phone;
  final String bio;
  final String? imagePath;

  Profile({
    this.name = 'Your Name',
    this.email = 'you@example.com',
    this.phone = '0000000000',
    this.bio = 'Offline profile details stored locally.',
    this.imagePath,
  });

  Profile copyWith({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? imagePath,
    bool clearImage = false,
  }) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
      'imagePath': imagePath,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      name: map['name'] ?? 'Your Name',
      email: map['email'] ?? 'you@example.com',
      phone: map['phone'] ?? '0000000000',
      bio: map['bio'] ?? 'Offline profile details stored locally.',
      imagePath: map['imagePath'],
    );
  }
}
