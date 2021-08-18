class DisplayUser {
  /// this is aquivalent to the KZL
  final String name;

  String? full_name;
  String? full_surname;

  DisplayUser(this.name, {this.full_name, this.full_surname});

  @override
  String toString() {
    return (full_name!=null && full_surname!=null)?'${full_name?[0]}. $full_surname': name;
  }
}

class User extends DisplayUser {
  final String pass;

  User(name, this.pass, {full_name, full_surname})
      : super(name, full_name: full_name, full_surname: full_surname);

  /*factory User.fromMap(Map<String, dynamic> map){
    return User(map['name'],map[''])
  }*/

  Map<String, dynamic> toJson() => {
        'name': name,
        'pass': pass,
      };
}
