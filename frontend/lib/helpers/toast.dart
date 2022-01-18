import 'package:fluttertoast/fluttertoast.dart' as FT;

showToast(String message) => FT.Fluttertoast.showToast(
      msg: message,
      toastLength: FT.Toast.LENGTH_SHORT,
      gravity: FT.ToastGravity.CENTER,
    );
