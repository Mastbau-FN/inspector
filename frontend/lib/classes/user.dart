class User {
  final String name;
  final String pass;
  const User(this.name, this.pass);

  Map<String, dynamic> toJson() => {
        'name': name,
        'pass': pass,
      };
}
