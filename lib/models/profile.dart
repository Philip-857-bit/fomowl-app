class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? primaryWalletAddress;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.primaryWalletAddress,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      primaryWalletAddress: json['primary_wallet_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'primary_wallet_address': primaryWalletAddress,
    };
  }
}
