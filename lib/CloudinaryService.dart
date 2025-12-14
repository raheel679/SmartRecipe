import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  final String cloudName = "smartrecipe"; // Your Cloudinary cloud name
  final String uploadPreset = "smartrecipe"; // The preset name, not ID

  Future<String?> uploadImage(File imageFile) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resData = await http.Response.fromStream(response);
      final data = json.decode(resData.body);
      return data["secure_url"]; // ✅ This is the uploaded image URL
    } else {
      print("Upload failed: ${response.statusCode}");
      return null;
    }
  }
}
