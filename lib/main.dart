import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://wfdkaehqnsshtbtgyfsg.supabase.co',
    anonKey: 'sb_publishable__ffHojA5LILq8W-lo9_cPg_4KIQg33N',
  );
  
  runApp(const MindfulApp());
  
}

// Глобальная переменная для доступа
final supabase = Supabase.instance.client;
