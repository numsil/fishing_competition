import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  try {
    print('Testing Supabase Connection...');
    
    // Load .env file manually for Dart script
    final envVars = await File('.env').readAsString();
    final envMap = <String, String>{};
    for (var line in envVars.split('\n')) {
      if (line.contains('=')) {
        final parts = line.split('=');
        envMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }

    final url = envMap['SUPABASE_URL'] ?? '';
    final key = envMap['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || key.isEmpty) {
      print('❌ Failed: URL or Key is empty');
      return;
    }

    print('URL: $url');
    final supabase = SupabaseClient(url, key);

    // Try to query the users table to test the connection
    print('Querying the database...');
    final response = await supabase.from('users').select().limit(1);
    
    print('✅ Success! Successfully connected to Supabase.');
    print('Response: $response');
    
  } catch (e) {
    print('❌ Connection Failed!');
    print(e.toString());
  }
}
